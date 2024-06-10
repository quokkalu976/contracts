const {getConfig} = require("./config.js");
const {AddressZero, HashZero} = require('@ethersproject/constants');

/*
hardhat deploy --network bscTestnet --tags 7
*/

module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const config = getConfig(await getChainId());

    log("7 add priceFeed start".padEnd(66, '.'));
    const feedInfos = await read('RollDex', 'chainlinkPriceFeeds');
    console.log("chainlink Feeds", feedInfos);
    // read from config.js
    for (const token of config.tokens.filter(token => token.priceFeed)
        .filter(token => !feedInfos.some(feedInfo => token.address.toLowerCase() === feedInfo.token.toLowerCase()))) {
        console.log("add chainlink for ", token.name, token.address)
        await execute(
            'RollDex', {from: deployer, log: true}, 'addChainlinkPriceFeed', token.address, token.priceFeed
        );
    }

    // // 0x3e57d6946f893314324C975AA9CEBBdF3232967E
    // const tradeHash = "0xf140b9383f520ef7bb1d44b2133c659ee7ea1ff6cf7ebc80f8994e348a2737f0";
    // // const token = config.tokens.filter(token => token.name === "BTC")[0];

    // // // price callback
    // // let tx = await execute(
    // //     'RollDex', {from: deployer, log: true}, 'requestPrice', tradeHash, token.address, 1
    // // );
    // // if (tx && tx.events) {
    // //     const requestId = tx.events.slice(-2)[0].topics[1];
    // //     console.log("requestId:", requestId)

    // //     // 67773_30130870, decimal 8
    // //     await execute(
    // //         'RollDex', {from: deployer, log: true}, 'requestPriceCallback', requestId, 6777330130870
    // //     );
    // // }
    // const token = config.tokens.filter(token => token.name === "USDT")[0];

    // // price callback
    // let tx = await execute(
    //     'RollDex', {from: deployer, log: true}, 'requestPrice', tradeHash, token.address, 1
    // );
    // if (tx && tx.events) {
    //     const requestId = tx.events.slice(-2)[0].topics[1];
    //     console.log("requestId:", requestId)

    //     // 67773_30130870, decimal 8
    //     await execute(
    //         'RollDex', {from: deployer, log: true}, 'requestPriceCallback', requestId, 99945999
    //     );
    // }
    

    // await execute(
    //     'RollDex', {from: deployer, log: true}, 'removeChainlinkPriceFeed', "0x54F5E8e4C65c0b3522CbD3CCDEe75f4b6c75345A"
    // );

    log("7 init chainlink & add priceFeed end".padStart(66, '.'));
}

module.exports.tags = ['priceFeed', '7'];
module.exports.dependencies = [];