// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../utils/Constants.sol";
import "../../utils/TransferHelper.sol";
import "../security/OnlySelf.sol";
import "../interfaces/IFeeManager.sol";
import "../interfaces/IPairsManager.sol";
import "../interfaces/ITradingClose.sol";
import "../interfaces/ITradingChecker.sol";
import "../libraries/LibTrading.sol";
import "../libraries/LibAccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";

contract TradingCloseFacet is ITradingClose, OnlySelf {

    using TransferHelper for address;
    using SignedMath for int256;

    function closeTradeCallback(bytes32 tradeHash, uint upperPrice, uint lowerPrice) external onlySelf override {
        LibTrading.TradingStorage storage ts = LibTrading.tradingStorage();
        OpenTrade storage ot = ts.openTrades[tradeHash];
        uint256 marketPrice;
        if (ot.isLong) {
            marketPrice = lowerPrice < ot.takeProfit ? lowerPrice : ot.takeProfit;
        } else {
            marketPrice = upperPrice > ot.takeProfit ? upperPrice : ot.takeProfit;
        }

        uint256 closePrice = ITradingCore(address(this)).slippagePrice(ot.pairBase, marketPrice, ot.qty, !ot.isLong);

        CloseInfo memory closeInfo = _closeTrade(ts, ot, tradeHash, marketPrice, closePrice);
        emit CloseTradeSuccessful(ot.user, tradeHash, closeInfo);
        _removeOpenTrade(ts, ot, tradeHash);
    }

    function _closeTrade(
        LibTrading.TradingStorage storage ts, OpenTrade storage ot,
        bytes32 tradeHash, uint256 marketPrice, uint256 closePrice
    ) private returns (CloseInfo memory) {
        int256 longAccFundingFeePerShare = ITradingCore(address(this)).updatePairPositionInfo(ot.pairBase, ot.entryPrice, marketPrice, ot.qty, ot.isLong, false);

        IVault.MarginToken memory mt = IVault(address(this)).getTokenForTrading(ot.tokenIn);

        int256 fundingFee = LibTrading.calcFundingFee(ot, mt, marketPrice, longAccFundingFeePerShare);
        uint256 holdingFee = LibTrading.calcHoldingFee(ot, mt);

        uint256 closeNotionalUsd = closePrice * ot.qty;
        int256 pnl;
        if (ot.isLong) {
            pnl = (int256(closeNotionalUsd) - int256(uint256(ot.entryPrice) * ot.qty)) * int256(10 ** mt.decimals) / int256(1e10 * mt.price);
        } else {
            pnl = (int256(uint256(ot.entryPrice) * ot.qty) - int256(closeNotionalUsd)) * int256(10 ** mt.decimals) / int256(1e10 * mt.price);
        }
        uint256 closeFee = LibTrading.calcCloseFee(IPairsManager(address(this)).getPairFeeConfig(ot.pairBase), mt, closeNotionalUsd, pnl);
        
        (closeFee, holdingFee) = _settleForCloseTrade(ts, ot, tradeHash, pnl, fundingFee, closeFee, holdingFee);

        return CloseInfo(
            uint64(closePrice), int96(fundingFee), uint96(closeFee), int96(pnl), uint96(holdingFee)
        );
    }

    function _settleForCloseTrade(
        LibTrading.TradingStorage storage ts, ITrading.OpenTrade memory ot,
        bytes32 tradeHash, int256 pnl, int256 fundingFee, uint256 closeFee, uint256 holdingFee
    ) private returns (uint256, uint256) {
        // openTradeReceive + closeFee + userReceive + lpReceive == 0
        // closeFee >= 0 && userReceive >= 0
        
        int256 openTradeReceive = - int256(uint256(ot.margin)) - fundingFee;
        
        uint256 userReceive;
        int256 lpReceive;
        // initialMargin+fundingFee+pnl
        if (- openTradeReceive + pnl >= int256(closeFee)) {
            // positive
            userReceive = uint256(- openTradeReceive + pnl) - closeFee;
            if (userReceive > holdingFee) {
                userReceive -= holdingFee;
            } else {
                holdingFee = userReceive;
                userReceive = 0;
            }
            lpReceive = - pnl + int256(holdingFee);
        } else if (- openTradeReceive + pnl > 0 && - openTradeReceive + pnl < int256(closeFee)) {
            closeFee = uint256(- openTradeReceive + pnl);
            lpReceive = - pnl;
            holdingFee = 0;
        } else {
            lpReceive = - openTradeReceive;
            closeFee = 0;
            holdingFee = 0;
        }

        _settleAsset(ts, SettleAssetTuple(ot, tradeHash, openTradeReceive, closeFee, userReceive, lpReceive));
        return (closeFee, holdingFee);
    }

    struct SettleAssetTuple {
        ITrading.OpenTrade ot;
        bytes32 tradeHash;
        int256 openTradeReceive;
        uint256 closeFee;
        uint256 userReceive;
        int256 lpReceive;
    }

    function _settleAsset(LibTrading.TradingStorage storage ts, SettleAssetTuple memory tuple) private {
        if (tuple.openTradeReceive < 0) {
            ITradingClose.SettleToken[] memory openTradeSettleTokens = _decreaseByCloseTrade(ts, tuple.ot.tokenIn, tuple.openTradeReceive.abs());
            if (tuple.lpReceive < 0) {// |openTradeReceive + lpReceive| = userReceive + closeFee
                ITradingClose.SettleToken[] memory lpSettleTokens = IVault(address(this)).decreaseByCloseTrade(tuple.ot.tokenIn, tuple.lpReceive.abs());
                require(
                    openTradeSettleTokens[0].amount + lpSettleTokens[0].amount >= tuple.closeFee,
                    string(
                        abi.encodePacked(
                            "TradingCloseFacet: [L&O] insufficient ", Strings.toHexString(tuple.ot.tokenIn),
                            ", O ", Strings.toString(openTradeSettleTokens[0].amount),
                            ", L ", Strings.toString(lpSettleTokens[0].amount),
                            ", F ", Strings.toString(tuple.closeFee)
                        )
                    )
                );
                if (tuple.closeFee > 0) {
                    IFeeManager(address(this)).chargeCloseFee(tuple.ot.tokenIn, tuple.closeFee, tuple.ot.broker);
                }
                if (tuple.userReceive > 0) {
                    lpSettleTokens[0].amount = lpSettleTokens[0].amount + openTradeSettleTokens[0].amount - tuple.closeFee;
                    _transferToUserForClose(tuple.tradeHash, tuple.ot.user, lpSettleTokens);

                    openTradeSettleTokens[0].amount = 0;
                    _transferToUserForClose(tuple.tradeHash, tuple.ot.user, openTradeSettleTokens);
                }
            } else if (tuple.lpReceive == 0) {// |openTradeReceive| = userReceive + closeFee
                require(
                    openTradeSettleTokens[0].amount >= tuple.closeFee,
                    string(
                        abi.encodePacked(
                            "TradingCloseFacet: [O] insufficient ", Strings.toHexString(tuple.ot.tokenIn),
                            ", O ", Strings.toString(openTradeSettleTokens[0].amount),
                            ", F ", Strings.toString(tuple.closeFee)
                        )
                    )
                );
                if (tuple.closeFee > 0) {
                    IFeeManager(address(this)).chargeCloseFee(tuple.ot.tokenIn, tuple.closeFee, tuple.ot.broker);
                }
                if (tuple.userReceive > 0) {
                    openTradeSettleTokens[0].amount -= tuple.closeFee;
                    _transferToUserForClose(tuple.tradeHash, tuple.ot.user, openTradeSettleTokens);
                }
            } else {// |openTradeReceive| = userReceive + closeFee + lpReceive
                require(
                    openTradeSettleTokens[0].amount >= tuple.closeFee,
                    string(
                        abi.encodePacked(
                            "TradingCloseFacet: [O] insufficient ", Strings.toHexString(tuple.ot.tokenIn),
                            ", F ", Strings.toString(tuple.closeFee),
                            ", O ", Strings.toString(openTradeSettleTokens[0].amount)
                        )
                    )
                );
                if (tuple.closeFee > 0) {
                    IFeeManager(address(this)).chargeCloseFee(tuple.ot.tokenIn, tuple.closeFee, tuple.ot.broker);
                }
                openTradeSettleTokens[0].amount -= tuple.closeFee;
                _transferToUserForClose(ts, tuple.tradeHash, tuple.ot.user, openTradeSettleTokens, tuple.userReceive, true);
            }
        } else if (tuple.openTradeReceive == 0) {
            if (tuple.lpReceive < 0) {// |lpReceive| = userReceive + closeFee
                ITradingClose.SettleToken[] memory lpSettleTokens = IVault(address(this)).decreaseByCloseTrade(tuple.ot.tokenIn, tuple.lpReceive.abs());
                require(
                    lpSettleTokens[0].amount >= tuple.closeFee,
                    string(
                        abi.encodePacked(
                            "TradingCloseFacet: [L] insufficient ", Strings.toHexString(tuple.ot.tokenIn),
                            ", L ", Strings.toString(lpSettleTokens[0].amount),
                            ", F ", Strings.toString(tuple.closeFee)
                        )
                    )
                );
                if (tuple.closeFee > 0) {
                    IFeeManager(address(this)).chargeCloseFee(tuple.ot.tokenIn, tuple.closeFee, tuple.ot.broker);
                }
                if (tuple.userReceive > 0) {
                    lpSettleTokens[0].amount -= tuple.closeFee;
                    _transferToUserForClose(tuple.tradeHash, tuple.ot.user, lpSettleTokens);
                }
            }
        } else {
            if (tuple.lpReceive < 0) {// |lpReceive| = userReceive + closeFee + openTradeReceive
                ITradingClose.SettleToken[] memory lpSettleTokens = IVault(address(this)).decreaseByCloseTrade(tuple.ot.tokenIn, tuple.lpReceive.abs());
                require(
                    lpSettleTokens[0].amount >= tuple.closeFee,
                    string(
                        abi.encodePacked(
                            "TradingCloseFacet: [L] insufficient ", Strings.toHexString(tuple.ot.tokenIn),
                            ", F ", Strings.toString(tuple.closeFee),
                            ", L ", Strings.toString(lpSettleTokens[0].amount)
                        )
                    )
                );
                if (tuple.closeFee > 0) {
                    IFeeManager(address(this)).chargeCloseFee(tuple.ot.tokenIn, tuple.closeFee, tuple.ot.broker);
                }
                lpSettleTokens[0].amount -= tuple.closeFee;
                _transferToUserForClose(ts, tuple.tradeHash, tuple.ot.user, lpSettleTokens, tuple.userReceive, false);
            }
        }
    }

    function _decreaseByCloseTrade(
        LibTrading.TradingStorage storage ts, address token, uint256 amount
    ) private returns (ITradingClose.SettleToken[] memory settleTokens) {
        IVault.MarginToken memory mt_0 = IVault(address(this)).getTokenForTrading(token);
        ITradingClose.SettleToken memory st = ITradingClose.SettleToken(
            token,
            ts.openTradeAmountIns[token] >= amount ? amount : ts.openTradeAmountIns[token],
            mt_0.decimals
        );

        if (ts.openTradeAmountIns[token] >= amount) {
            ts.openTradeAmountIns[token] -= amount;
            settleTokens = new ITradingClose.SettleToken[](1);
            settleTokens[0] = st;
            return settleTokens;
        } else {
            require(ts.openTradeTokenIns.length >= 1, "TradingClose: Insufficient funds in the openTradeTokens");
            // if not sufficient in this token, try other tokens
            uint256 otherTokenAmountUsd = (amount - ts.openTradeAmountIns[token]) * mt_0.price * 1e10 / (10 ** mt_0.decimals);

            ITrading.MarginBalance[] memory balances = new ITrading.MarginBalance[](ts.openTradeTokenIns.length - 1);
            uint256 totalBalanceUsd;
            UC index = ZERO;
            for (UC i = ZERO; i < uc(ts.openTradeTokenIns.length); i = i + ONE) {
                address tokenIn = ts.openTradeTokenIns[i.into()];
                if (tokenIn != token && ts.openTradeAmountIns[tokenIn] > 0) {
                    IVault.MarginToken memory mt = IVault(address(this)).getTokenForTrading(tokenIn);
                    uint balanceUsd = mt.price * ts.openTradeAmountIns[tokenIn] * 1e10 / (10 ** mt.decimals);
                    balances[index.into()] = ITrading.MarginBalance(tokenIn, mt.price, mt.decimals, balanceUsd);
                    totalBalanceUsd += balanceUsd;
                    index = index + ONE;
                }
            }
            //require(otherTokenAmountUsd <= totalBalanceUsd, "Insufficient funds, use other token");
            require(
                    otherTokenAmountUsd <= totalBalanceUsd, 
                    string(
                        abi.encodePacked(
                            "Insufficient funds, require ", Strings.toString(otherTokenAmountUsd),
                            " <= ", Strings.toString(totalBalanceUsd),
                            " , ", Strings.toString(mt_0.price),
                            " len=", Strings.toString(ts.openTradeTokenIns.length)
                        )
                    )
                );

            settleTokens = new ITradingClose.SettleToken[]((index + ONE).into());
            settleTokens[0] = st;
            ts.openTradeAmountIns[token] = 0;
            if (index.into() > 0) {
                uint points = 1e4;
                for (UC i = ONE; i < index; i = i + ONE) {
                    ITrading.MarginBalance memory mb = balances[i.into()];
                    uint256 share = mb.balanceUsd * 1e4 / totalBalanceUsd;
                    settleTokens[i.into()] = ITradingClose.SettleToken(mb.token, otherTokenAmountUsd * share * (10 ** mb.decimals) / (1e4 * 1e10 * mb.price), mb.decimals);
                    ts.openTradeAmountIns[mb.token] -= settleTokens[i.into()].amount;
                    points -= share;
                }
                ITrading.MarginBalance memory b = balances[0];
                settleTokens[index.into()] = ITradingClose.SettleToken(b.token, otherTokenAmountUsd * points * (10 ** b.decimals) / (1e4 * 1e10 * b.price), b.decimals);
                ts.openTradeAmountIns[b.token] -= settleTokens[index.into()].amount;
            }
            return settleTokens;
        }
    }

    function _closeTradeReceived(bytes32 tradeHash, address to, address token, uint256 amount) private {
        token.transfer(to, amount);
        emit CloseTradeReceived(to, tradeHash, token, amount);
    }

    function _transferToUserForClose(bytes32 tradeHash, address to, ITradingClose.SettleToken[] memory settleTokens) private {
        for (UC i = ZERO; i < uc(settleTokens.length); i = i + ONE) {
            if (settleTokens[i.into()].amount > 0) {
                _closeTradeReceived(tradeHash, to, settleTokens[i.into()].token, settleTokens[i.into()].amount);
            }
        }
    }

    function _transferToUserForClose(
        LibTrading.TradingStorage storage ts, bytes32 tradeHash, address to,
        ITradingClose.SettleToken[] memory settleTokens,
        uint256 userReceive, bool toLp
    ) private {
        if (settleTokens[0].amount >= userReceive) {
            if (userReceive > 0) {
                _closeTradeReceived(tradeHash, to, settleTokens[0].token, userReceive);
                settleTokens[0].amount -= userReceive;
            }
            for (UC i = ZERO; i < uc(settleTokens.length); i = i + ONE) {
                if (settleTokens[i.into()].amount > 0) {
                    if (toLp) {
                        IVault(address(this)).increase(settleTokens[i.into()].token, settleTokens[i.into()].amount);
                        emit CloseTradeAddLiquidity(settleTokens[i.into()].token, settleTokens[i.into()].amount);
                    } else {
                        LibTrading.increaseOpenTradeAmount(ts, settleTokens[i.into()].token, settleTokens[i.into()].amount);
                    }
                }
            }
        } else {
            if (userReceive > 0) {
                if (settleTokens[0].amount > 0) {
                    _closeTradeReceived(tradeHash, to, settleTokens[0].token, settleTokens[0].amount);
                }
                uint256 userReceiveUsd = (userReceive - settleTokens[0].amount) * IPriceFacade(address(this)).getPrice(settleTokens[0].token) * 1e10 / (10 ** settleTokens[0].decimals);
                for (UC i = ONE; i < uc(settleTokens.length); i = i + ONE) {
                    if (settleTokens[i.into()].amount > 0) {
                        uint256 price = IPriceFacade(address(this)).getPrice(settleTokens[i.into()].token);
                        uint256 valueUsd = settleTokens[i.into()].amount * price * 1e10 / (10 ** settleTokens[i.into()].decimals);
                        if (userReceiveUsd >= valueUsd) {
                            _closeTradeReceived(tradeHash, to, settleTokens[i.into()].token, settleTokens[i.into()].amount);
                            userReceiveUsd -= valueUsd;
                        } else if (userReceiveUsd > 0 && userReceiveUsd < valueUsd) {
                            userReceive = userReceiveUsd * (10 ** settleTokens[i.into()].decimals) / (price * 1e10);
                            _closeTradeReceived(tradeHash, to, settleTokens[i.into()].token, userReceive);
                            if (toLp) {
                                IVault(address(this)).increase(settleTokens[i.into()].token, settleTokens[i.into()].amount - userReceive);
                                emit CloseTradeAddLiquidity(settleTokens[i.into()].token, settleTokens[i.into()].amount - userReceive);
                            } else {
                                LibTrading.increaseOpenTradeAmount(ts, settleTokens[i.into()].token, settleTokens[i.into()].amount - userReceive);
                            }
                            userReceiveUsd = 0;
                        } else {
                            if (toLp) {
                                IVault(address(this)).increase(settleTokens[i.into()].token, settleTokens[i.into()].amount);
                                emit CloseTradeAddLiquidity(settleTokens[i.into()].token, settleTokens[i.into()].amount);
                            } else {
                                LibTrading.increaseOpenTradeAmount(ts, settleTokens[i.into()].token, settleTokens[i.into()].amount);
                            }
                        }
                    }
                }
                require(userReceiveUsd == 0, "TradingCloseFacet: Insufficient funds in the openTrade");
            }
        }
    }

    function executeTpSlOrLiq(TpSlOrLiq[] memory arr) external override {
        LibAccessControlEnumerable.checkRole(Constants.KEEPER_ROLE);
        require(arr.length > 0, "TradingCloseFacet: Parameters are empty");
        LibTrading.TradingStorage storage ts = LibTrading.tradingStorage();
        for (UC i = ZERO; i < uc(arr.length); i = i + ONE) {
            TpSlOrLiq memory t = arr[i.into()];
            ITrading.OpenTrade storage ot = ts.openTrades[t.tradeHash];
            if (ot.margin == 0) {
                continue;
            }
            (bool available, uint64 upper, uint64 lower) = IPriceFacade(address(this)).confirmTriggerPrice(ot.pairBase, t.price);
            if (!available) {
                emit ExecuteCloseRejected(ot.user, t.tradeHash, t.executionType, t.price, 0);
                continue;
            }
            uint64 marketPrice;
            if (ot.isLong) {
                marketPrice = lower < ot.takeProfit ? lower : ot.takeProfit;
            } else {
                marketPrice = upper > ot.takeProfit ? upper : ot.takeProfit;
            }
            uint256 closePrice = ITradingCore(address(this)).slippagePrice(ot.pairBase, marketPrice, ot.qty, !ot.isLong);
            if (t.executionType == ExecutionType.TP) {
                if ((ot.isLong && marketPrice < ot.takeProfit) || (!ot.isLong && marketPrice > ot.takeProfit)) {
                    emit ExecuteCloseRejected(ot.user, t.tradeHash, t.executionType, t.price, marketPrice);
                    continue;
                }
                _executeTp(ts, ot, t.tradeHash, marketPrice, closePrice);
            } else if (t.executionType == ExecutionType.SL) {
                if ((ot.isLong && marketPrice > ot.stopLoss) || (!ot.isLong && marketPrice < ot.stopLoss)) {
                    emit ExecuteCloseRejected(ot.user, t.tradeHash, t.executionType, t.price, marketPrice);
                    continue;
                }
                _executeSl(ts, ot, t.tradeHash, marketPrice, closePrice);
            } else {
                _executeLiq(ts, ot, t, marketPrice, closePrice);
            }
        }
    }

    function _executeTp(
        LibTrading.TradingStorage storage ts, ITrading.OpenTrade storage ot,
        bytes32 tradeHash, uint64 marketPrice, uint256 closePrice
    ) private {
        CloseInfo memory closeInfo = _closeTrade(ts, ot, tradeHash, marketPrice, closePrice);
        emit ExecuteCloseSuccessful(ot.user, tradeHash, ExecutionType.TP, closeInfo);
        _removeOpenTrade(ts, ot, tradeHash);
    }

    function _executeSl(
        LibTrading.TradingStorage storage ts, ITrading.OpenTrade storage ot,
        bytes32 tradeHash, uint64 marketPrice, uint256 closePrice
    ) private {
        CloseInfo memory closeInfo = _closeTrade(ts, ot, tradeHash, marketPrice, closePrice);
        emit ExecuteCloseSuccessful(ot.user, tradeHash, ExecutionType.SL, closeInfo);
        _removeOpenTrade(ts, ot, tradeHash);
    }

    function _executeLiq(
        LibTrading.TradingStorage storage ts, ITrading.OpenTrade storage ot,
        TpSlOrLiq memory t, uint64 marketPrice, uint256 closePrice
    ) private {
        (bool needLiq, int256 pnl, int256 fundingFee, uint256 closeFee, uint256 holdingFee) =
        ITradingChecker(address(this)).executeLiquidateCheck(ot, marketPrice, closePrice);
        if (!needLiq) {
            emit ExecuteCloseRejected(ot.user, t.tradeHash, ExecutionType.LIQ, t.price, marketPrice);
            return;
        }

        ITradingCore(address(this)).updatePairPositionInfo(ot.pairBase, ot.entryPrice, marketPrice, ot.qty, ot.isLong, false);
        (closeFee, holdingFee) = _settleForLiqTrade(ts, ot, t.tradeHash, pnl, fundingFee, closeFee, holdingFee);

        CloseInfo memory closeInfo = CloseInfo(
            uint64(closePrice), int96(fundingFee), uint96(closeFee), int96(pnl), uint96(holdingFee)
        );
        emit ExecuteCloseSuccessful(ot.user, t.tradeHash, ExecutionType.LIQ, closeInfo);
        _removeOpenTrade(ts, ot, t.tradeHash);
    }

    function _settleForLiqTrade(
        LibTrading.TradingStorage storage ts, ITrading.OpenTrade memory ot,
        bytes32 tradeHash, int256 pnl, int256 fundingFee, uint256 closeFee, uint256 holdingFee
    ) private returns (uint256, uint256) {
        // userReceive = 0
        // openTradeReceive + closeFee + lpReceive == 0
        // closeFee >= 0
        int256 openTradeReceive = - int256(uint256(ot.margin)) - fundingFee;
        uint256 userReceive;
        int256 lpReceive;
        if (- openTradeReceive + pnl >= int256(closeFee)) {
            userReceive = uint256(- openTradeReceive + pnl) - closeFee;
            lpReceive = - pnl;
        } else if (- openTradeReceive + pnl > 0 && - openTradeReceive + pnl < int256(closeFee)) {
            closeFee = uint256(- openTradeReceive + pnl);
            lpReceive = - pnl;
            holdingFee = 0;
        } else {
            lpReceive = - openTradeReceive;
            closeFee = 0;
            holdingFee = 0;
        }
        // The user's position is covered by the LP, and any excess funds are held by the LP upon liquidation
        if (userReceive > 0) {
            holdingFee = userReceive < holdingFee ? userReceive : holdingFee;
            lpReceive += int256(userReceive);
            userReceive = 0;
        }
        _settleAsset(ts, SettleAssetTuple(ot, tradeHash, openTradeReceive, closeFee, userReceive, lpReceive));
        return (closeFee, holdingFee);
    }


    function _removeOpenTrade(
        LibTrading.TradingStorage storage ts,
        ITrading.OpenTrade storage ot,
        bytes32 tradeHash
    ) private {
        bytes32[] storage userTradeHashes = ts.userOpenTradeHashes[ot.user];
        uint256 last = userTradeHashes.length - 1;
        uint256 tradeIndex = ot.userOpenTradeIndex;
        if (tradeIndex != last) {
            bytes32 lastTradeHash = userTradeHashes[last];
            userTradeHashes[tradeIndex] = lastTradeHash;
            ts.openTrades[lastTradeHash].userOpenTradeIndex = uint32(tradeIndex);
        }
        userTradeHashes.pop();
        delete ts.openTrades[tradeHash];
    }
}
