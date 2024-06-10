const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 28
*/
const pairName = 'BTC/USD';
module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer, multisig} = await getNamedAccounts();
    const config = getConfig(await getChainId());

    log("28 tp ratio start".padEnd(66, '.'));

    const pair = config.pairs.filter(p => p.name === pairName)[0];
    const maxTakeProfits = await read('RollDex', 'getPairMaxTpRatios', pair.base);
    
    if (maxTakeProfits.length > 0) {
        console.log("maxTakeProfits", maxTakeProfits);
    } else {
        console.log("no configured maxTakeProfits for pair");
        const tradingConfig = await read('RollDex', 'getTradingConfig');
        console.log("use default trading config", tradingConfig);

        //setMaxTakeProfitP()
    }

    // await execute(
    //     'RollDex', { from: deployer, log: true }, 'setMinNotionalUsd', 50
    // );

    await execute(
        'RollDex', { from: deployer, log: true }, 'setMaxTakeProfitP', 55000
    );

    // // leverage, maxTakeProfitP;
    // const maxTpRatios = [[485, 0], [750, 55000], [1000, 35000]]
    // await execute(
    //     'RollDex', { from: deployer, log: true }, 'setMaxTpRatioForLeverage', maxTpRatios
    // );

    

    log("28 tp ratio end".padStart(66, '.'));
}

module.exports.tags = ['tpRatio', '28'];
module.exports.dependencies = [];