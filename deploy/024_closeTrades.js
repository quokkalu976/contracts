const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 24
*/
const tokenIn = 'USBTDT', pairName = 'ETH/USD', amountIn = '200';
module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const config = getConfig(await getChainId());
    log("24 closePositions start".padEnd(66, '.'));

    const token = config.tokens.filter(token => token.name === tokenIn)[0];
    const tokenAddresses = config.tokens.map(token => token.address);

    const pair = config.pairs.filter(p => p.name === pairName)[0];
    console.log("pair:", pair);


    // read from pendingMarketTrade event
    // const tradeHash = '0xcb6aefc677eda2f0af577bc9fa1feb7b49c2f95e274c8c953880ce9836d0010c';
                       
    // const pendingTrade = await read(
    //     'RollDex', {from: deployer, log: true}, 'getPendingTrade', tradeHash
    // );
    // console.log("pendingTrade", pendingTrade)

    // let {price, updatedAt} = await read('RollDex', 'getPriceFromCacheOrOracle', pair.base);
    // console.log(ethers.formatUnits(price.toBigInt(), 8));
    // let tx = await execute(
    //     'RollDex', {from: deployer, log: true}, 'requestPriceCallback', "0x27c08c1cd7be24495791e3ae7891c7e6dcf1577c19355492081be695da78fa2d", price
    // );
    // if (tx) {
    //     console.log(tx);
    // }

    const marketInfo = await read('RollDex', 'getMarketInfo',  pair.base);
    console.log("marketInfo", marketInfo);

    // let rolldex = await get('RollDex');
    // console.log("addr: ", rolldex.address);



    // console.log("GET trader assets", tokenAddresses);
    // const traderAssets = await read('RollDex', 'traderAssets', tokenAddresses);
    // console.log("temp deposit traderAssets", traderAssets);

    // for (const tokenAddr of tokenAddresses) {
    //     const tokenInfo = await read('RollDex', 'getTokenForTrading', tokenAddr);
    //     console.log("get trading token info, should include price", tokenInfo, ethers.formatUnits(tokenInfo.price.toBigInt(), tokenInfo.decimals) );
    // }


    const positions = await read('RollDex', 'getPositionsV2', deployer, pair.base);
    console.log("positions", positions);
    for (const position of positions) {
        
        if (position.pair === pairName) {
            console.log('close position:', position)
            let tx = await execute(
                'RollDex', {from: deployer, log: true}, 'closeTrade', position.positionHash
            );

            if (tx && tx.events) {
                // get requestId from the last event
                const requestId = tx.events.slice(-1)[0].topics[1];
                console.log("requestId:", requestId)
        
                await new Promise(r => setTimeout(r, 15*1000));

                let {price, updatedAt} = await read('RollDex', 'getPriceFromCacheOrOracle', pair.base);
                log(`${pair.name} price from oracle: ${Math.round(Date.now() / 1000) - updatedAt}s ago`, ethers.formatUnits(price.toBigInt(), 8));


                // price callback
                await execute(
                    'RollDex', {from: deployer, log: true}, 'requestPriceCallback', requestId, price
                );
            }
        }
    }
    

    log("24 closePositions end".padStart(66, '.'));
}

module.exports.tags = ['24'];
module.exports.dependencies = [''];