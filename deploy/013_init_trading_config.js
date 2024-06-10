const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 13
*/

module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const config = getConfig(await getChainId());
    log("13 init trading config start".padEnd(66, '.'));

    const tradingConfig = await read('RollDex', 'getTradingConfig');
    console.log(tradingConfig);

    if (tradingConfig.executionFeeUsd === 0 && tradingConfig.minNotionalUsd === 0 && tradingConfig.maxTakeProfitP === 0) {
        // uint256 executionFeeUsd, 
        // uint256 minNotionalUsd, 
        // uint24 maxTakeProfitP, 
        // uint256 minBetUsd
        await execute(
            'RollDex', {from: deployer, log: true}, 'initTradingConfigFacet', 
            ethers.parseEther('0.2'),
            ethers.parseEther('100'), 55000, ethers.parseEther('10')
        );
    }

    for (const pair of config.pairs.filter(pair => pair.maxTpRatios)) {
        const maxTps = await read('RollDex', 'getPairMaxTpRatios', pair.base);
        console.log(maxTps)
        // if (!maxTps || !maxTps.length) {
            await execute(
                'RollDex', {from: deployer, log: true}, 'setMaxTpRatioForLeverage', pair.base, pair.maxTpRatios
            )
        // }
    }

    log("13 init trading config end".padStart(66, '.'));
}

module.exports.tags = ['13'];
module.exports.dependencies = ['priceFeed', 'pairs'];