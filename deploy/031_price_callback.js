const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 31
*/
const tokenIn = 'USBTDT', pairName = 'BTC/USD', amountIn = '200';
module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const config = getConfig(await getChainId());
    log("31 priceCallback start".padEnd(66, '.'));

    const pair = config.pairs.filter(p => p.name === pairName)[0];
    console.log("pair:", pair);


    // read from pendingMarketTrade event
    // const tradeHash = '0xcb6aefc677eda2f0af577bc9fa1feb7b49c2f95e274c8c953880ce9836d0010c';
                       
    // const pendingTrade = await read(
    //     'RollDex', {from: deployer, log: true}, 'getPendingTrade', tradeHash
    // );
    // console.log("pendingTrade", pendingTrade)

    let {price, updatedAt} = await read('RollDex', 'getPriceFromCacheOrOracle', pair.base);
    console.log(ethers.formatUnits(price.toBigInt(), 8));
    let tx = await execute(
        'RollDex', {from: deployer, log: true}, 'requestPriceCallback', "0x992b56421a5262396e2b4eaff3111394d2b296e9debeb3e37686dd0e09008ede", price
    );
    if (tx) {
        console.log(tx);
    }

    log("31 priceCallback end".padStart(66, '.'));
}

module.exports.tags = ['31'];
module.exports.dependencies = [''];