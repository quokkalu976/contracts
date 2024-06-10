const {getConfig} = require("./config");
const {AddressZero, HashZero} = require('@ethersproject/constants');

/*
hardhat deploy --network bscTestnet --tags 27
*/

module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer, multisig} = await getNamedAccounts();
    const config = getConfig(await getChainId());

    log("27 update slippage start".padEnd(66, '.'));


    await execute(
        'RollDex', {from: deployer, log: true}, 'setMaxDelay', 20000
    );

    for (const sc of config.slippages) {
        const [slippage, _] = await read('RollDex', "getSlippageConfigByIndex", sc.id);
        if (!slippage || !slippage.enable) {
            await execute(
                'RollDex', {from: deployer, log: true}, 'addSlippageConfig', sc.name, sc.id, sc.slippageConfig
            );
        } else {
            console.log("slippage", slippage);
            
            /**
             *     struct UpdateSlippageConfigParam {
                        uint16 index;
                        SlippageType slippageType;
                        uint256 onePercentDepthAboveUsd;
                        uint256 onePercentDepthBelowUsd;
                        uint16 slippageLongP;    // 1e4
                        uint16 slippageShortP;   // 1e4
                        uint256 longThresholdUsd;
                        uint256 shortThresholdUsd;
                    }
             */
            const slippageConfig = {};
            slippageConfig.index = sc.id;
            slippageConfig.slippageType = sc.slippageConfig.slippageType;
            slippageConfig.onePercentDepthAboveUsd = sc.slippageConfig.onePercentDepthAboveUsd;
            slippageConfig.onePercentDepthBelowUsd = sc.slippageConfig.onePercentDepthBelowUsd;
            slippageConfig.slippageLongP= sc.slippageConfig.slippageLongP;
            slippageConfig.slippageShortP= sc.slippageConfig.slippageShortP;
            slippageConfig.longThresholdUsd= sc.slippageConfig.longThresholdUsd;
            slippageConfig.shortThresholdUsd= sc.slippageConfig.shortThresholdUsd;
            console.log("config", slippageConfig);

            await execute(
                'RollDex', {from: deployer, log: true}, 'updateSlippageConfig', slippageConfig
            );
        }
    }

    log("27 update slippage end".padStart(66, '.'));
}

module.exports.tags = ['slippage', '27'];
module.exports.dependencies = [];