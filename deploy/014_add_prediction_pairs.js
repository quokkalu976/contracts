const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 14
*/

module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const config = getConfig(await getChainId());
    log("14 add prediction pair start".padEnd(66, '.'));

    const predictPairViews = await read('RollDex', "predictionPairs", 0, 100);
    for (const pair of config.predictionPairs
        .filter(pair => !predictPairViews.some(pv => pv.base.toLowerCase() === pair.base.toLowerCase()))) {
        await execute(
            'RollDex', {from: deployer, log: true}, 'addPredictionPair', pair.base, pair.name, pair.predictionPeriods
        );
    }

    log("14 add prediction pair end".padStart(66, '.'));
}

module.exports.tags = ['14'];
module.exports.dependencies = ['priceFeed'];