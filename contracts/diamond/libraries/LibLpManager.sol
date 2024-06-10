// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../utils/Constants.sol";
import "../libraries/LibVault.sol";
import "../interfaces/IPriceFacade.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

library LibLpManager {

    bytes32 constant LP_MANAGER_STORAGE_POSITION = keccak256("lp.manager.storage.v2");
    uint8 constant LP_DECIMALS = 18;

    struct LpManagerStorage {
        mapping(address => uint256) lastMintedAt;
        uint256 coolingDuration;
        address lpAddress;
        mapping(address account => bool) freeBurnWhitelists;
        uint256 safeguard;  // obsolete
    }

    function lpManagerStorage() internal pure returns (LpManagerStorage storage ams) {
        bytes32 position = LP_MANAGER_STORAGE_POSITION;
        assembly {
            ams.slot := position
        }
    }

    function initialize(address lpToken) internal {
        LpManagerStorage storage ams = lpManagerStorage();
        require(ams.lpAddress == address(0), "LibLpManager: Already initialized");
        ams.lpAddress = lpToken;
	    // need 30mins from mint to burnLP
        ams.coolingDuration = 30 minutes;
    }

    event MintAddLiquidity(address indexed account, address indexed token, uint256 amount);
    event BurnRemoveLiquidity(address indexed account, address indexed token, uint256 amount);
    event MintFee(
        address indexed account, address indexed tokenIn, uint256 amountIn,
        uint256 tokenInPrice, uint256 mintFeeUsd, uint256 lpAmount
    );
    event BurnFee(
        address indexed account, address indexed tokenOut, uint256 amountOut,
        uint256 tokenOutPrice, uint256 burnFeeUsd, uint256 lpAmount
    );

    function lpPrice() internal view returns (uint256) {
        int256 totalValueUsd = LibVault.getTotalValueUsd();
        int256 lpUnPnlUsd = ITradingCore(address(this)).lpUnrealizedPnlTotalUsd();
        return _lpPrice(totalValueUsd + lpUnPnlUsd);
    }

    function _lpPrice(int256 totalValueUsd) private view returns (uint256) {
        uint256 totalSupply = IERC20(lpManagerStorage().lpAddress).totalSupply();
        if (totalValueUsd <= 0 && totalSupply > 0) {
            return 0;
        }
        if (totalSupply == 0) {
            // default to 1
            return 1e8;
        } else {
            return uint256(totalValueUsd) * 1e8 / totalSupply;
        }
    }

    function mintLP(address account, address tokenIn, uint256 amount) internal returns (uint256 lpAmount){
        LibVault.AvailableToken memory at = LibVault.vaultStorage().tokens[tokenIn];
        lpAmount = _calculateLpAmount(at, amount);
        IVault(address(this)).increase(tokenIn, amount);
        _addMinted(account);
        emit MintAddLiquidity(account, tokenIn, amount);
    }

    function _calculateLpAmount(LibVault.AvailableToken memory at, uint256 amount) private returns (uint256 lpAmount) {
        require(at.tokenAddress != address(0), "LibLpManager: Token does not exist");

        (int256 lpUnPnlUsd, int256 lpTokenUnPnlUsd) = ITradingCore(address(this)).lpUnrealizedPnlUsd(at.tokenAddress);
        int256 totalValueUsd = LibVault.getTotalValueUsd() + lpUnPnlUsd;
        require(totalValueUsd >= 0, "LibLpManager: LP balance is insufficient");

        (uint256 tokenInPrice,) = IPriceFacade(address(this)).getPriceFromCacheOrOracle(at.tokenAddress);
        uint256 amountUsd = tokenInPrice * amount * 1e10 / (10 ** at.decimals);
        // tokenInUSD + unPNL portion
        int256 poolTokenInUsd = int256(LibVault.vaultStorage().treasury[at.tokenAddress] * tokenInPrice * 1e10 / (10 ** at.decimals)) + lpTokenUnPnlUsd;

        // after tax = amountUsd * (1-fee)
        uint256 afterTaxAmountUsd = amountUsd * (1e4 - _getFeePoint(at, uint256(totalValueUsd), poolTokenInUsd, amountUsd, true)) / 1e4;
        lpAmount = afterTaxAmountUsd * 1e8 / _lpPrice(totalValueUsd);
        emit MintFee(msg.sender, at.tokenAddress, amount, tokenInPrice, amountUsd - afterTaxAmountUsd, lpAmount);
    }

    function _addMinted(address account) private {
        lpManagerStorage().lastMintedAt[account] = block.timestamp;
    }

    function burnLP(address account, address tokenOut, uint256 lpAmount) internal returns (uint256 amountOut) {
        LpManagerStorage storage ams = lpManagerStorage();
        require(
            ams.freeBurnWhitelists[account] || (ams.lastMintedAt[account] + ams.coolingDuration <= block.timestamp),
            string(
                abi.encodePacked(
                    "Cooling duration after last LP token mint, seconds=", Strings.toString(ams.coolingDuration)
                )
            )
        );
        LibVault.AvailableToken memory at = LibVault.vaultStorage().tokens[tokenOut];
        amountOut = _calculateTokenAmount(at, lpAmount);
        emit BurnRemoveLiquidity(account, tokenOut, amountOut);
    }

    function _calculateTokenAmount(LibVault.AvailableToken memory at, uint256 lpAmount) private returns (uint256 amountOut) {
        require(at.tokenAddress != address(0), "LibLpManager: Token does not exist");
        (int256 lpUnPnlUsd, int256 lpTokenUnPnlUsd) = ITradingCore(address(this)).lpUnrealizedPnlUsd(at.tokenAddress);
        int256 totalValueUsd = LibVault.getTotalValueUsd() + lpUnPnlUsd;
        require(totalValueUsd > 0, "LibLpManager: LP balance is insufficient");

        (uint256 tokenOutPrice,) = IPriceFacade(address(this)).getPriceFromCacheOrOracle(at.tokenAddress);
        int256 poolTokenOutUsd = int256(LibVault.vaultStorage().treasury[at.tokenAddress] * tokenOutPrice * 1e10 / (10 ** at.decimals)) + lpTokenUnPnlUsd;
        uint256 amountOutUsd = _lpPrice(totalValueUsd) * lpAmount / 1e8;
        // It is not allowed for the value of any token in the LP to become negative after burning.
        require(poolTokenOutUsd >= int256(amountOutUsd), "LP has insufficient funds for this withdrawal");
        uint256 afterTaxAmountOutUsd = amountOutUsd * (1e4 - _getFeePoint(at, uint256(totalValueUsd), poolTokenOutUsd, amountOutUsd, false)) / 1e4;
        require(int256(afterTaxAmountOutUsd) <= LibVault.maxWithdrawAbleUsd(totalValueUsd), "LP has insufficient funds for this withdrawal after fee");
        amountOut = afterTaxAmountOutUsd * (10 ** at.decimals) / (tokenOutPrice * 1e10);
        emit BurnFee(msg.sender, at.tokenAddress, amountOut, tokenOutPrice, amountOutUsd - afterTaxAmountOutUsd, lpAmount);
        return amountOut;
    }

    function _getFeePoint(
        LibVault.AvailableToken memory at, uint256 totalValueUsd,
        int256 poolTokenUsd, uint256 amountUsd, bool increase
    ) private pure returns (uint256) {
        if (!at.dynamicFee) {
            return increase ? at.feeBasisPoints : at.taxBasisPoints;
        }
        uint256 targetValueUsd = totalValueUsd * at.weight / 1e4;
        int256 nextValueUsd = poolTokenUsd + int256(amountUsd);
        if (!increase) {
            // ∵ poolTokenUsd >= amountUsd && amountUsd > 0
            // ∴ poolTokenUsd > 0
            nextValueUsd = poolTokenUsd - int256(amountUsd);
        }

        uint256 initDiff = poolTokenUsd > int256(targetValueUsd)
            ? uint256(poolTokenUsd) - targetValueUsd  // ∵ (poolTokenUsd > targetValueUsd && targetValueUsd > 0) ∴ (poolTokenUsd > 0)
            : uint256(int256(targetValueUsd) - poolTokenUsd);

        uint256 nextDiff = nextValueUsd > int256(targetValueUsd)
            ? uint256(nextValueUsd) - targetValueUsd
            : uint256(int256(targetValueUsd) - nextValueUsd);

        if (nextDiff < initDiff) {
            uint256 feeAdjust = at.taxBasisPoints * initDiff / targetValueUsd;
            return at.feeBasisPoints > feeAdjust ? at.feeBasisPoints - feeAdjust : 0;
        }

        uint256 avgDiff = (initDiff + nextDiff) / 2;
        return at.feeBasisPoints + (avgDiff > targetValueUsd ? at.taxBasisPoints : (at.taxBasisPoints * avgDiff) / targetValueUsd);
    }
}