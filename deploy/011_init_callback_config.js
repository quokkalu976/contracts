
/*
hardhat deploy --network bscTestnet --tags 11
*/

module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer} = await getNamedAccounts();

    log("11 init callback config start".padEnd(66, '.'));

    const callbackConfig = await read('RollDex', 'getPriceFacadeConfig');
    if (callbackConfig.lowPriceGapP === 0 && callbackConfig.highPriceGapP === 0 && callbackConfig.maxDelay === 0) {
        await execute(
            'RollDex', {from: deployer, log: true}, 'initPriceFacadeFacet', 120, 150, 65535
        );
    }

    if (callbackConfig.triggerLowPriceGapP === 0 && callbackConfig.triggerHighPriceGapP === 0) {
        await execute(
            'RollDex', {from: deployer, log: true}, 'setTriggerLowAndHighPriceGapP', 499, 500
        );
    }

    log("11 init callback config end".padStart(66, '.'));
}

module.exports.tags = ['11'];
module.exports.dependencies = [];