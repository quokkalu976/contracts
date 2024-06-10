const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 23
*/
const tokenIn = 'USDT', pairName = 'BTC/USD', amountIn = '200';
module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const config = getConfig(await getChainId());
    log("23 getLimitOrders start".padEnd(66, '.'));

    const pair = config.pairs.filter(p => p.name === pairName)[0];

    const limitOrders = await read('RollDex', 'getLimitOrders', deployer, pair.base);
    console.log("limitOrders", limitOrders);

    if (!limitOrders.length) {
        for (const order of limitOrders) {
            console.log('cancel order:', order.orderHash)
            await execute(
                'RollDex', {from: deployer, log: true}, 'cancelLimitOrder', order.orderHash
            );
        }
    }

    log("23 getLimitOrders end".padStart(66, '.'));
}

module.exports.tags = ['23'];
module.exports.dependencies = [''];