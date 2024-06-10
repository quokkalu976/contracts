// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ISlippageManager.sol";
import "../libraries/LibAccessControlEnumerable.sol";
import {ISlippageManagerError} from "../../utils/Errors.sol";

contract SlippageManagerFacet is ISlippageManager, ISlippageManagerError {

    function addSlippageConfig(
        string calldata name, uint16 index, SlippageConfigView calldata sc
    ) external override {
        LibAccessControlEnumerable.checkRole(Constants.PAIR_OPERATOR_ROLE);
        if (sc.slippageLongP >= 1e4 || sc.slippageShortP >= 1e4) {
            revert InvalidSlippage(sc.slippageLongP, sc.slippageShortP);
        }
        if (sc.slippageType != SlippageType.FIXED && (sc.onePercentDepthAboveUsd == 0 || sc.onePercentDepthBelowUsd == 0)) {
            revert InvalidOnePercentDepthUsd(sc.onePercentDepthAboveUsd, sc.onePercentDepthBelowUsd);
        }

        LibPairsManager.SlippageConfig storage config = LibPairsManager.pairsManagerStorage().slippageConfigs[index];
        if (config.enable) revert ExistentSlippage(config.index, config.name);
        config.index = index;
        config.name = name;
        config.enable = true;
        config.slippageType = sc.slippageType;
        config.onePercentDepthAboveUsd = sc.onePercentDepthAboveUsd;
        config.onePercentDepthBelowUsd = sc.onePercentDepthBelowUsd;
        config.slippageLongP = sc.slippageLongP;
        config.slippageShortP = sc.slippageShortP;
        config.longThresholdUsd = sc.longThresholdUsd;
        config.shortThresholdUsd = sc.shortThresholdUsd;
        emit AddSlippageConfig(
            index, sc.slippageType, sc.onePercentDepthAboveUsd, sc.onePercentDepthBelowUsd,
            sc.slippageLongP, sc.slippageShortP, sc.longThresholdUsd, sc.shortThresholdUsd, name
        );
    }

    function removeSlippageConfig(uint16 index) external override {
        LibAccessControlEnumerable.checkRole(Constants.PAIR_OPERATOR_ROLE);
        LibPairsManager.PairsManagerStorage storage pms = LibPairsManager.pairsManagerStorage();
        LibPairsManager.SlippageConfig storage config = pms.slippageConfigs[index];
        if (!config.enable) revert NonexistentSlippage(index);
        if (pms.slippageConfigPairs[index].length != 0) revert SlippageInUse(index, config.name);
        delete pms.slippageConfigs[index];
        emit RemoveSlippageConfig(index);
    }

    function updateSlippageConfig(UpdateSlippageConfigParam calldata param) external override {
        LibAccessControlEnumerable.checkRole(Constants.MONITOR_ROLE);
        _updateSlippageConfig(param);
    }

    function batchUpdateSlippageConfig(UpdateSlippageConfigParam[] calldata params) external override {
        LibAccessControlEnumerable.checkRole(Constants.MONITOR_ROLE);
        for (uint256 i = 0; i < params.length;) {
            UpdateSlippageConfigParam calldata param = params[i];
            _updateSlippageConfig(param);
            unchecked {++i;}
        }
    }

    function _updateSlippageConfig(UpdateSlippageConfigParam calldata sc) private {
        if (sc.slippageLongP >= 1e4 || sc.slippageShortP >= 1e4) {
            revert InvalidSlippage(sc.slippageLongP, sc.slippageShortP);
        }
        if (sc.slippageType != SlippageType.FIXED && (sc.onePercentDepthAboveUsd == 0 || sc.onePercentDepthBelowUsd == 0)) {
            revert InvalidOnePercentDepthUsd(sc.onePercentDepthAboveUsd, sc.onePercentDepthBelowUsd);
        }

        LibPairsManager.SlippageConfig storage config = LibPairsManager.pairsManagerStorage().slippageConfigs[sc.index];
        if (!config.enable) revert NonexistentSlippage(sc.index);
        config.slippageType = sc.slippageType;
        config.onePercentDepthAboveUsd = sc.onePercentDepthAboveUsd;
        config.onePercentDepthBelowUsd = sc.onePercentDepthBelowUsd;
        config.slippageLongP = sc.slippageLongP;
        config.slippageShortP = sc.slippageShortP;
        config.longThresholdUsd = sc.longThresholdUsd;
        config.shortThresholdUsd = sc.shortThresholdUsd;
        emit UpdateSlippageConfig(
            sc.index, sc.slippageType, sc.onePercentDepthAboveUsd, sc.onePercentDepthBelowUsd,
            sc.slippageLongP, sc.slippageShortP, sc.longThresholdUsd, sc.shortThresholdUsd
        );
    }

    function getSlippageConfigByIndex(uint16 index) external view override returns (LibPairsManager.SlippageConfig memory, IPairsManager.PairSimple[] memory) {
        LibPairsManager.PairsManagerStorage storage pms = LibPairsManager.pairsManagerStorage();
        LibPairsManager.SlippageConfig memory config = pms.slippageConfigs[index];
        address[] memory slippagePairs = pms.slippageConfigPairs[index];
        IPairsManager.PairSimple[] memory pairSimples = new IPairsManager.PairSimple[](slippagePairs.length);
        if (slippagePairs.length > 0) {
            mapping(address => LibPairsManager.Pair) storage _pairs = LibPairsManager.pairsManagerStorage().pairs;
            for (uint i; i < slippagePairs.length; i++) {
                LibPairsManager. Pair storage pair = _pairs[slippagePairs[i]];
                pairSimples[i] = IPairsManager.PairSimple(pair.name, pair.base, pair.pairType, pair.status);
            }
        }
        return (config, pairSimples);
    }
}
