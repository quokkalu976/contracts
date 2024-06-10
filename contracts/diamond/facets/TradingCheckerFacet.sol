// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../utils/Constants.sol";
import "../interfaces/IVault.sol";
import "../interfaces/ILimitOrder.sol";
import "../interfaces/IPriceFacade.sol";
import "../interfaces/ITradingCore.sol";
import "../interfaces/IPairsManager.sol";
import "../interfaces/ITradingConfig.sol";
import "../interfaces/ITradingChecker.sol";
import "../libraries/LibTrading.sol";
import {ZERO, ONE, UC, uc, into} from "unchecked-counter/src/UC.sol";

contract TradingCheckerFacet is ITradingChecker {

    struct CheckTpTuple {
        address pairBase;
        bool isLong;
        uint256 takeProfit;
        uint256 entryPrice;
        uint256 leverage_10000;
    }

    function _checkTp(CheckTpTuple memory tuple) private view returns (bool) {
        return checkTp(tuple.pairBase, tuple.isLong, tuple.takeProfit, tuple.entryPrice, tuple.leverage_10000);
    }

    function checkTp(
        address pairBase, bool isLong, uint takeProfit, uint entryPrice, uint leverage_10000
    ) public view returns (bool) {
        uint maxTakeProfitP = ITradingConfig(address(this)).getPairMaxTpRatio(pairBase, leverage_10000);
        if (isLong) {
            // The takeProfit price must be set and the percentage of profit must not exceed the maximum allowed
            return takeProfit > entryPrice && (takeProfit - entryPrice) * leverage_10000 <= maxTakeProfitP * entryPrice;
        } else {
            // The takeProfit price must be set and the percentage of profit must not exceed the maximum allowed
            return takeProfit > 0 && takeProfit < entryPrice && (entryPrice - takeProfit) * leverage_10000 <= maxTakeProfitP * entryPrice;
        }
    }

    function checkSl(bool isLong, uint stopLoss, uint entryPrice) public pure returns (bool) {
        if (isLong) {
            // stopLoss price below the liquidation price is meaningless
            // But no check is done here and is intercepted by the front-end.
            // (entryPrice - stopLoss) * qty < marginUsd * liqLostP / Constants.1e4
            return stopLoss == 0 || stopLoss < entryPrice;
        } else {
            // stopLoss price below the liquidation price is meaningless
            // But no check is done here and is intercepted by the front-end.
            // (stopLoss - entryPrice) * qty * 1e4 < marginUsd * liqLostP
            return stopLoss == 0 || stopLoss > entryPrice;
        }
    }

    function checkLimitOrderTp(ILimitOrder.LimitOrder calldata order) external view override {
        IVault.MarginToken memory token = IVault(address(this)).getTokenForTrading(order.tokenIn);

        // notionalUsd = price * qty
        uint notionalUsd = uint256(order.limitPrice) * order.qty;

        // openFeeUsd = notionalUsd * openFeeP
        uint openFeeUsd = notionalUsd * IPairsManager(address(this)).getPairFeeConfig(order.pairBase).openFeeP / 1e4;

        // marginUsd = amountInUsd - openFeeUsd - executionFeeUsd
        uint marginUsd = order.amountIn * token.price * 1e10 / (10 ** token.decimals) - openFeeUsd - ITradingConfig(address(this)).getTradingConfig().executionFeeUsd;

        // leverage_10000 = notionalUsd * 10000 / marginUsd
        uint leverage_10000 = notionalUsd * 1e4 / marginUsd;

        require(
            checkTp(order.pairBase, order.isLong, order.takeProfit, order.limitPrice, leverage_10000),
            "TradingCheckerFacet: takeProfit is not in the valid range"
        );
    }

    function _checkParameters(IBook.OpenDataInput calldata data) private pure {
        require(
            data.qty > 0 && data.amountIn > 0 && data.price > 0
            && data.pairBase != address(0) && data.tokenIn != address(0),
            "TradingCheckerFacet: Invalid parameters"
        );
    }

    function openLimitOrderCheck(IBook.OpenDataInput calldata data) external view override {
        _checkParameters(data);

        IVault.MarginToken memory token = IVault(address(this)).getTokenForTrading(data.tokenIn);
        require(token.switchOn, "TradingCheckerFacet: This token is not supported as margin");

        IPairsManager.TradingPair memory pair = IPairsManager(address(this)).getPairForTrading(data.pairBase);
        require(pair.status == IPairsManager.PairStatus.AVAILABLE, "TradingCheckerFacet: The pair is temporarily unavailable for trading");

        ITradingConfig.TradingConfig memory tc = ITradingConfig(address(this)).getTradingConfig();
        require(tc.limitOrder, "TradeChecker: This feature is temporarily disabled");

        (uint marketPrice,) = IPriceFacade(address(this)).getPriceFromCacheOrOracle(data.pairBase);
        require(marketPrice > 0, "TradeChecker: No access to current market effective prices");

        uint triggerPrice = ITradingCore(address(this)).triggerPrice(data.pairBase, data.price, data.qty, data.isLong);
        require(
            (data.isLong && triggerPrice < marketPrice) || (!data.isLong && triggerPrice > marketPrice),
            "TradeChecker: This limit order will be filled immediately"
        );

        // price * qty * 10^18 / 10^(8+10) = price * qty
        uint notionalUsd = uint256(data.price) * data.qty;
        // The notional value must be greater than or equal to the minimum notional value allowed
        require(notionalUsd >= tc.minNotionalUsd, "TradeChecker: Position is too small");

        IPairsManager.LeverageMargin[] memory lms = pair.leverageMargins;
        // The notional value of the position must be less than or equal to the maximum notional value allowed by pair
        require(notionalUsd <= lms[lms.length - 1].notionalUsd, "TradeChecker: Position is too large");

        IPairsManager.LeverageMargin memory lm = _marginLeverage(lms, notionalUsd);
        uint openFeeUsd = notionalUsd * pair.feeConfig.openFeeP / 1e4;
        uint amountInUsd = data.amountIn * token.price * 1e10 / (10 ** token.decimals);
        require(amountInUsd > openFeeUsd + tc.executionFeeUsd, "TradingCheckerFacet: The amount is too small");

        // marginUsd = amountInUsd - openFeeUsd - executionFeeUsd
        uint marginUsd = amountInUsd - openFeeUsd - tc.executionFeeUsd;
        // leverage = notionalUsd / marginUsd
        uint leverage_10000 = notionalUsd * 1e4 / marginUsd;
        require(
            leverage_10000 <= uint(1e4) * lm.maxLeverage,
            "TradingCheckerFacet: Exceeds the maximum leverage allowed for the position"
        );
        // require(
        //     _checkTp(CheckTpTuple(data.pairBase, data.isLong, data.takeProfit, data.price, leverage_10000)),
        //     "TradingCheckerFacet: takeProfit is not in the valid range"
        // );
        // require(
        //     checkSl(data.isLong, data.stopLoss, data.price),
        //     "TradingCheckerFacet: stopLoss is not in the valid range"
        // );
    }

    struct ExecuteLimitOrderCheckTuple {
        IPairsManager.TradingPair pair;
        ITradingConfig.TradingConfig tc;
        IVault.MarginToken token;
        ITradingCore.PairQty pairQty;
        uint notionalUsd;
        uint triggerPrice;
    }

    function _buildExecuteLimitOrderCheckTuple(
        ILimitOrder.LimitOrder memory order
    ) private view returns (ExecuteLimitOrderCheckTuple memory) {
        IPairsManager.TradingPair memory pair = IPairsManager(address(this)).getPairForTrading(order.pairBase);
        ITradingCore.PairQty memory pairQty = ITradingCore(address(this)).getPairQty(order.pairBase);
        return ExecuteLimitOrderCheckTuple(
            pair,
            ITradingConfig(address(this)).getTradingConfig(),
            IVault(address(this)).getTokenForTrading(order.tokenIn),
            pairQty,
            uint256(order.limitPrice) * order.qty,
            ITradingCore(address(this)).triggerPrice(pairQty, pair.slippageConfig, order.limitPrice, order.qty, order.isLong)
        );
    }

    function executeLimitOrderCheck(
        ILimitOrder.LimitOrder memory order,
        uint256 marketPrice
    ) external view override returns (bool result, uint96 openFee, uint96 executionFee, Refund refund) {
        ExecuteLimitOrderCheckTuple memory tuple = _buildExecuteLimitOrderCheckTuple(order);
        if (!tuple.tc.executeLimitOrder) {
            return (false, 0, 0, Refund.SWITCH);
        }

        if (tuple.pair.base == address(0) || tuple.pair.status != IPairsManager.PairStatus.AVAILABLE) {
            return (false, 0, 0, Refund.PAIR_STATUS);
        }

        if (tuple.notionalUsd < tuple.tc.minNotionalUsd) {
            return (false, 0, 0, Refund.MIN_NOTIONAL_USD);
        }

        IPairsManager.LeverageMargin[] memory lms = tuple.pair.leverageMargins;
        if (tuple.notionalUsd > lms[lms.length - 1].notionalUsd) {
            return (false, 0, 0, Refund.MAX_NOTIONAL_USD);
        }

        IPairsManager.LeverageMargin memory lm = _marginLeverage(lms, tuple.notionalUsd);
        uint openFeeUsd = tuple.notionalUsd * tuple.pair.feeConfig.openFeeP / 1e4;
        uint amountInUsd = order.amountIn * tuple.token.price * 1e10 / (10 ** tuple.token.decimals);
        if (amountInUsd <= openFeeUsd + tuple.tc.executionFeeUsd) {
            return (false, 0, 0, Refund.AMOUNT_IN);
        }

        // marginUsd = amountInUsd - openFeeUsd - executionFeeUsd
        uint marginUsd = amountInUsd - openFeeUsd - tuple.tc.executionFeeUsd;
        // leverage_10000 = notionalUsd * 10000 / marginUsd
        uint leverage_10000 = tuple.notionalUsd * 1e4 / marginUsd;
        if (leverage_10000 > uint(1e4) * lm.maxLeverage) {
            return (false, 0, 0, Refund.MAX_LEVERAGE);
        }

        if (order.isLong) {
            if (marketPrice > tuple.triggerPrice) {
                return (false, 0, 0, Refund.USER_PRICE);
            }
            // Whether the Stop Loss will be triggered immediately at the current price
            if (marketPrice <= order.stopLoss) {
                return (false, 0, 0, Refund.SL);
            }
            // pair OI check
            if (tuple.notionalUsd + tuple.pairQty.longQty * marketPrice > tuple.pair.pairConfig.maxLongOiUsd) {
                return (false, 0, 0, Refund.PAIR_OI);
            }
            // open lost check
            if ((order.limitPrice - marketPrice) * order.qty * 1e4 >= marginUsd * lm.initialLostP) {
                return (false, 0, 0, Refund.OPEN_LOST);
            }
        } else {
            // Comparison of the values of price and limitPrice + slippage
            if (marketPrice < tuple.triggerPrice) {
                return (false, 0, 0, Refund.USER_PRICE);
            }
            // 4. Whether the Stop Loss will be triggered immediately at the current price
            if (order.stopLoss > 0 && marketPrice >= order.stopLoss) {
                return (false, 0, 0, Refund.SL);
            }
            // pair OI check
            if (tuple.notionalUsd + tuple.pairQty.shortQty * marketPrice > tuple.pair.pairConfig.maxShortOiUsd) {
                return (false, 0, 0, Refund.PAIR_OI);
            }
            // open lost check
            if ((marketPrice - order.limitPrice) * order.qty * 1e4 >= marginUsd * lm.initialLostP) {
                return (false, 0, 0, Refund.OPEN_LOST);
            }
        }
        return (true,
            uint96(openFeeUsd * (10 ** tuple.token.decimals) / (1e10 * tuple.token.price)),
            uint96(tuple.tc.executionFeeUsd * (10 ** tuple.token.decimals) / (1e10 * tuple.token.price)),
            Refund.NO
        );
    }

    function checkMarketTradeTp(ITrading.OpenTrade calldata ot) external view {
        IVault.MarginToken memory token = IVault(address(this)).getTokenForTrading(ot.tokenIn);

        // notionalUsd = price * qty
        uint notionalUsd = uint256(ot.entryPrice) * ot.qty;

        // marginUsd = margin * token.price
        uint marginUsd = ot.margin * token.price * 1e10 / (10 ** token.decimals);

        // leverage_10000 = notionalUsd * 10000 / marginUsd
        uint leverage_10000 = notionalUsd * 1e4 / marginUsd;

        require(
            checkTp(ot.pairBase, ot.isLong, ot.takeProfit, ot.entryPrice, leverage_10000),
            "TradingCheckerFacet: takeProfit is not in the valid range"
        );
    }

    function openMarketTradeCheck(IBook.OpenDataInput calldata data) external view override {
        _checkParameters(data);

        IVault.MarginToken memory token = IVault(address(this)).getTokenForTrading(data.tokenIn);
        require(token.switchOn, "This token is not supported as collateral");

        IPairsManager.TradingPair memory pair = IPairsManager(address(this)).getPairForTrading(data.pairBase);
        require(pair.status == IPairsManager.PairStatus.AVAILABLE, "The pair is temporarily unavailable for trading");

        ITradingConfig.TradingConfig memory tc = ITradingConfig(address(this)).getTradingConfig();
        require(tc.marketTrading, "This feature is disabled");

        (uint marketPrice,) = IPriceFacade(address(this)).getPriceFromCacheOrOracle(data.pairBase);
        require(marketPrice > 0, "No available market price from oracle");

        ITradingCore.PairQty memory pairQty = ITradingCore(address(this)).getPairQty(data.pairBase);
        // marketPrice +- slippage
        uint trialPrice = ITradingCore(address(this)).slippagePrice(pairQty, pair.slippageConfig, marketPrice, data.qty, data.isLong);
        require(
            (data.isLong && trialPrice <= data.price) || (!data.isLong && trialPrice >= data.price),
            "Unable to trade at a preferable price, please increase slippage"
        );

        // price * qty * 10^18 / 10^(8+10) = price * qty
        uint notionalUsd = trialPrice * data.qty;
        // The notional value must be greater than or equal to the minimum notional value allowed
        require(notionalUsd >= tc.minNotionalUsd, "Notional value too small");

        IPairsManager.LeverageMargin[] memory lms = pair.leverageMargins;
        // The notional value of the position must be less than or equal to the maximum notional value allowed by pair
        require(notionalUsd <= lms[lms.length - 1].notionalUsd, "Notional value too large");

        // find corresponding lerverage config
        IPairsManager.LeverageMargin memory lm = _marginLeverage(lms, notionalUsd);
        
        uint openFeeUsd = notionalUsd * pair.feeConfig.openFeeP / 1e4;
        uint amountInUsd = data.amountIn * token.price * 1e10 / (10 ** token.decimals);
        require(amountInUsd > openFeeUsd + tc.executionFeeUsd, "Not able to cover fee");

        // marginUsd = amountInUsd - openFeeUsd - executionFeeUsd
        uint marginUsd = amountInUsd - openFeeUsd - tc.executionFeeUsd;
        // leverage = notionalUsd / marginUsd
        uint leverage_10000 = notionalUsd * 1e4 / marginUsd;
        require(
            leverage_10000 <= uint(1e4) * lm.maxLeverage,
            "Exceeds the maximum leverage allowed, please reduce leverage"
        );
        
        require(
           _checkTp(_buildCheckTpTuple(data, trialPrice, leverage_10000)),
           "Reduce TakeProfit price"
        );
        require(
            checkSl(data.isLong, data.stopLoss, trialPrice),
            "StopLoss price should not cross entry price"
        );

        if (data.isLong) {
            // It is prohibited to open positions with excessive losses. Avoid opening positions that are liquidated
            require(
                (trialPrice - marketPrice) * data.qty * 1e4 < marginUsd * lm.initialLostP,
                "Too much initial loss"
            );
            // The total position must be less than or equal to the maximum position allowed for the trading pair
            require(notionalUsd + pairQty.longQty * trialPrice <= pair.pairConfig.maxLongOiUsd, "Long positions have exceeded the maximum allowed");
        } else {
            // It is prohibited to open positions with excessive losses. Avoid opening positions that are liquidated
            require(
                (marketPrice - trialPrice) * data.qty * 1e4 < marginUsd * lm.initialLostP,
                "Too much initial loss"
            );
            // The total position must be less than or equal to the maximum position allowed for the trading pair
            require(notionalUsd + pairQty.shortQty * trialPrice <= pair.pairConfig.maxShortOiUsd, "Short positions have exceeded the maximum allowed");
        }
    }

    function _buildCheckTpTuple(IBook.OpenDataInput calldata data, uint256 entryPrice, uint256 leverage_10000) private pure returns (CheckTpTuple memory) {
       return CheckTpTuple(data.pairBase, data.isLong, data.takeProfit, entryPrice, leverage_10000);
    }

    struct MarketTradeCallbackCheckTuple {
        IPairsManager.TradingPair pair;
        ITradingConfig.TradingConfig tc;
        IVault.MarginToken token;
        ITradingCore.PairQty pairQty;
        uint notionalUsd;
        uint entryPrice;
    }

    function _buildMarketTradeCallbackCheckTuple(
        ITrading.PendingTrade memory pt, uint256 marketPrice
    ) private view returns (MarketTradeCallbackCheckTuple memory) {
        IPairsManager.TradingPair memory pair = IPairsManager(address(this)).getPairForTrading(pt.pairBase);
        ITradingCore.PairQty memory pairQty = ITradingCore(address(this)).getPairQty(pt.pairBase);
        // marketPrice * 100.1% or marketPrice *99.9%
        uint entryPrice = ITradingCore(address(this)).slippagePrice(pairQty, pair.slippageConfig, marketPrice, pt.qty, pt.isLong);
        return MarketTradeCallbackCheckTuple(
            pair,
            ITradingConfig(address(this)).getTradingConfig(),
            IVault(address(this)).getTokenForTrading(pt.tokenIn),
            pairQty,
            entryPrice * pt.qty,
            entryPrice
        );
    }

    function _marginLeverage(
        IPairsManager.LeverageMargin[] memory lms, uint256 notionalUsd
    ) private pure returns (IPairsManager.LeverageMargin memory) {
        for (UC i = ZERO; i < uc(lms.length); i = i + ONE) {
            if (notionalUsd <= lms[i.into()].notionalUsd) {
                return lms[i.into()];
            }
        }
        return lms[lms.length - 1];
    }

    /// @return successful
    /// @return refund
    /// @return data (uint96 openFee, uint96 executionFee, uint64 entryPrice, uint64 takeProfit)
    function marketTradeCallbackCheck(
        ITrading.PendingTrade calldata pt, uint256 marketPrice
    ) external view returns (bool successful, Refund refund, bytes memory data) {
        //check block, now is within 10blocks
        if (pt.blockNumber + Constants.FEED_DELAY_BLOCK < block.number) {
            return (false, Refund.FEED_DELAY, data);
        }


        MarketTradeCallbackCheckTuple memory tuple = _buildMarketTradeCallbackCheckTuple(pt, marketPrice);
        // if long, real price (incl. slippage) > user price
        if ((pt.isLong && tuple.entryPrice > pt.price) || (!pt.isLong && tuple.entryPrice < pt.price)) {
            return (false, Refund.USER_PRICE, data);
        }

        // minNotional, configured by initTradingConfigFacet, default 100U
        if (tuple.notionalUsd < tuple.tc.minNotionalUsd) {
            return (false, Refund.MIN_NOTIONAL_USD, data);
        }

        // exceed pair's max notional, default 1M
        IPairsManager.LeverageMargin[] memory lms = tuple.pair.leverageMargins;
        if (tuple.notionalUsd > lms[lms.length - 1].notionalUsd) {
            return (false, Refund.MAX_NOTIONAL_USD, data);
        }


        IPairsManager.LeverageMargin memory lm = _marginLeverage(lms, tuple.notionalUsd);

        // tokenPrice is from oracle/cache
        uint openFeeUsd = tuple.notionalUsd * tuple.pair.feeConfig.openFeeP / 1e4;
        uint amountInUsd = pt.amountIn * tuple.token.price * 1e10 / (10 ** tuple.token.decimals);
        // amountIn < openFee + callback fee
        if (amountInUsd <= openFeeUsd + tuple.tc.executionFeeUsd) {
            return (false, Refund.AMOUNT_IN, data);
        }

        // marginUsd = amountInUsd - openFeeUsd - executionFeeUsd
        uint marginUsd = amountInUsd - openFeeUsd - tuple.tc.executionFeeUsd;
        // leverage_10000 = notionalUsd * 10000 / marginUsd
        uint leverage_10000 = tuple.notionalUsd * 1e4 / marginUsd;

        if (leverage_10000 > uint(1e4) * lm.maxLeverage) {
            return (false, Refund.MAX_LEVERAGE, data);
        }
        
        if (!checkSl(pt.isLong, pt.stopLoss, tuple.entryPrice)) {
            return (false, Refund.SL, data);
        }

        if (pt.isLong) {
            // pair OI check
            if (tuple.notionalUsd + tuple.pairQty.longQty * tuple.entryPrice > tuple.pair.pairConfig.maxLongOiUsd) {
                return (false, Refund.PAIR_OI, data);
            }
            // open lost check
            if ((tuple.entryPrice - marketPrice) * pt.qty * 1e4 >= marginUsd * lm.initialLostP) {
                return (false, Refund.OPEN_LOST, data);
            }
        } else {
            // pair OI check
            if (tuple.notionalUsd + tuple.pairQty.shortQty * tuple.entryPrice > tuple.pair.pairConfig.maxShortOiUsd) {
                return (false, Refund.PAIR_OI, data);
            }
            // open lost check
            if ((marketPrice - tuple.entryPrice) * pt.qty * 1e4 >= marginUsd * lm.initialLostP) {
                return (false, Refund.OPEN_LOST, data);
            }
        }

        return (true, Refund.NO, _buildMarketTradeCallbackResult(pt, tuple, openFeeUsd, leverage_10000));
    }

    function _buildMarketTradeCallbackResult(
        ITrading.PendingTrade calldata pt, MarketTradeCallbackCheckTuple memory tuple,
        uint openFeeUsd, uint leverage_10000
    ) private view returns (bytes memory) {
        return abi.encode(
            uint96(openFeeUsd * (10 ** tuple.token.decimals) / (1e10 * tuple.token.price)),
            uint96(tuple.tc.executionFeeUsd * (10 ** tuple.token.decimals) / (1e10 * tuple.token.price)),
            uint64(tuple.entryPrice),
            uint64(_availableTakeProfit(pt.pairBase, pt.isLong, pt.takeProfit, tuple.entryPrice, leverage_10000))
        );
    }

    function _availableTakeProfit(
        address pairBase, bool isLong, uint takeProfit, uint entryPrice, uint leverage_10000
    ) private view returns (uint256) {
        uint256 maxTakeProfitP = ITradingConfig(address(this)).getPairMaxTpRatio(pairBase, leverage_10000);
        uint256 maxTakeProfit;
        if (isLong) {
            maxTakeProfit = maxTakeProfitP * entryPrice / leverage_10000 + entryPrice;
            return takeProfit > maxTakeProfit || takeProfit <= entryPrice ? maxTakeProfit : takeProfit;
        } else {
            if (entryPrice <= maxTakeProfitP * entryPrice / leverage_10000) {
                maxTakeProfit = 0;
            } else {
                maxTakeProfit = entryPrice - maxTakeProfitP * entryPrice / leverage_10000;
            }
            return takeProfit < maxTakeProfit || takeProfit >= entryPrice ? maxTakeProfit : takeProfit;
        }
    }

    function _buildCheckTpTuple(ITrading.PendingTrade calldata pt, uint256 entryPrice, uint256 leverage_10000) private pure returns (CheckTpTuple memory) {
        return CheckTpTuple(pt.pairBase, pt.isLong, pt.takeProfit, entryPrice, leverage_10000);
    }

    function executeLiquidateCheck(
        ITrading.OpenTrade calldata ot, uint256 marketPrice, uint256 closePrice
    ) external view returns (bool needLiq, int256 pnl, int256 fundingFee, uint256 closeFee, uint256 holdingFee) {
        IVault.MarginToken memory mt = IVault(address(this)).getTokenForTrading(ot.tokenIn);
        IPairsManager.TradingPair memory pair = IPairsManager(address(this)).getPairForTrading(ot.pairBase);

        fundingFee = LibTrading.calcFundingFee(ot, mt, marketPrice);

        uint256 closeNotionalUsd = closePrice * ot.qty;
        holdingFee = _calcHoldingFee(ot, mt);
        if (ot.isLong) {
            pnl = (int256(closeNotionalUsd) - int256(uint256(ot.entryPrice) * ot.qty)) * int256(10 ** mt.decimals) / int256(1e10 * mt.price);
        } else {
            pnl = (int256(uint256(ot.entryPrice) * ot.qty) - int256(closeNotionalUsd)) * int256(10 ** mt.decimals) / int256(1e10 * mt.price);
        }
        closeFee = LibTrading.calcCloseFee(pair.feeConfig, mt, closeNotionalUsd, pnl);
        int256 loss = int256(closeFee) - fundingFee - pnl + int256(holdingFee);
        IPairsManager.LeverageMargin memory lm = _marginLeverage(pair.leverageMargins, uint256(ot.entryPrice) * ot.qty);
        return (loss > 0 && uint256(loss) * 1e4 >= lm.liqLostP * ot.margin, pnl, fundingFee, closeFee, holdingFee);
    }

    function _calcHoldingFee(ITrading.OpenTrade calldata ot, IVault.MarginToken memory mt) private view returns (uint256) {
        uint256 holdingFee;
        if (ot.holdingFeeRate > 0 && ot.openBlock > 0) {
            // holdingFeeRate 1e12
            holdingFee = uint256(ot.entryPrice) * ot.qty * (block.number - ot.openBlock) * ot.holdingFeeRate * (10 ** mt.decimals) / uint256(1e22 * mt.price);
        }
        return holdingFee;
    }
}
