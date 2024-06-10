// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/LibFeeManager.sol";
import "../libraries/LibPairsManager.sol";

// In order to be compatible with the front-end call before the release,
// temporary use, front-end all updated, this Facet can be removed.
contract TransitionFacet {

    struct SlippageConfig {
        string name;
        uint256 onePercentDepthAboveUsd;
        uint256 onePercentDepthBelowUsd;
        uint16 slippageLongP;       // 1e4
        uint16 slippageShortP;      // 1e4
        uint16 index;
        SlippageType slippageType;
        bool enable;
    }

    struct PairView {
        // BTC/USD
        string name;
        // BTC address
        address base;
        uint16 basePosition;
        IPairsManager.PairType pairType;
        IPairsManager.PairStatus status;
        uint256 maxLongOiUsd;
        uint256 maxShortOiUsd;
        uint256 fundingFeePerBlockP;  // 1e18
        uint256 minFundingFeeR;       // 1e18
        uint256 maxFundingFeeR;       // 1e18

        LibPairsManager.LeverageMargin[] leverageMargins;

        uint16 slippageConfigIndex;
        uint16 slippagePosition;
        SlippageConfig slippageConfig;

        uint16 feeConfigIndex;
        uint16 feePosition;
        LibFeeManager.FeeConfig feeConfig;

        uint40 longHoldingFeeRate;    // 1e12
        uint40 shortHoldingFeeRate;   // 1e12
    }

    function pairsV3() external view returns (PairView[] memory) {
        LibPairsManager.PairsManagerStorage storage pms = LibPairsManager.pairsManagerStorage();
        address[] memory bases = pms.pairBases;
        PairView[] memory pairViews = new PairView[](bases.length);
        for (uint i; i < bases.length; i++) {
            LibPairsManager.Pair storage pair = pms.pairs[bases[i]];
            pairViews[i] = _pairToView(pair, pms.slippageConfigs[pair.slippageConfigIndex]);
        }
        return pairViews;
    }

    function getPairByBaseV3(address base) external view returns (PairView memory) {
        LibPairsManager.PairsManagerStorage storage pms = LibPairsManager.pairsManagerStorage();
        LibPairsManager.Pair storage pair = pms.pairs[base];
        return _pairToView(pair, pms.slippageConfigs[pair.slippageConfigIndex]);
    }

    function _pairToView(
        LibPairsManager.Pair storage pair, LibPairsManager.SlippageConfig memory sc
    ) private view returns (PairView memory) {
        LibPairsManager.LeverageMargin[] memory leverageMargins = new LibPairsManager.LeverageMargin[](pair.maxTier);
        for (uint16 i = 0; i < pair.maxTier; i++) {
            leverageMargins[i] = pair.leverageMargins[i + 1];
        }
        (LibFeeManager.FeeConfig memory fc,) = LibFeeManager.getFeeConfigByIndex(pair.feeConfigIndex);
        SlippageConfig memory slippageConfig = SlippageConfig(
            sc.name, sc.onePercentDepthAboveUsd, sc.onePercentDepthBelowUsd, sc.slippageLongP,
            sc.slippageShortP, sc.index, sc.slippageType, sc.enable
        );
        PairView memory pv = PairView(
            pair.name, pair.base, pair.basePosition, pair.pairType, pair.status, pair.maxLongOiUsd, pair.maxShortOiUsd,
            pair.fundingFeePerBlockP, pair.minFundingFeeR, pair.maxFundingFeeR, leverageMargins,
            pair.slippageConfigIndex, pair.slippagePosition, slippageConfig,
            pair.feeConfigIndex, pair.feePosition, fc, pair.longHoldingFeeRate, pair.shortHoldingFeeRate
        );
        return pv;
    }
}
