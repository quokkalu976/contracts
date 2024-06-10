const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 26
*/
const tokenIn = 'USDT', pairName = 'BTC/USD', amountIn = '0.002';
module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const config = getConfig(await getChainId());
    log("26 openMarketTradeNative start".padEnd(66, '.'));

    const token = config.tokens.filter(token => token.name === tokenIn)[0];
    const pair = config.pairs.filter(p => p.name === pairName)[0];

    let {price} = await read('RollDex', 'getPriceFromCacheOrOracle', pair.base);

    log(`${pair.name} price from oracle:`, ethers.formatUnits(price.toBigInt(), 8));
    const isLong = Math.random() < 0.5;
    const orderPrice = (isLong ? price.mul(999) : price.mul(990)).div(1000); //   99.8% current price
    // let takeProfit = (isLong ? price.mul(1004) : price.mul(970)).div(1000); // take profit: 100.4% current price
    let takeProfit = isLong ? price.mul(1001).div(1000) : price.mul(999).div(1000); // take profit: 100.4% current price
    log(`takeProfit: ${ethers.formatUnits(takeProfit.toBigInt(), 8)}`);
    // log(`isLong: ${isLong}, price: ${ethers.formatUnits(orderPrice.toBigInt(), 8)}, takeProfit: ${ethers.formatUnits(takeProfit.toBigInt(), 8)}`);
 

    // price = (isLong ? price.mul(998) : price.mul(990)).div(1000);
    // let takeProfit = (isLong ? price.mul(1004) : price.mul(970)).div(1000);
    // log(`isLong: ${isLong}, price: ${ethers.formatUnits(price.toBigInt(), 8)}, takeProfit: ${ethers.formatUnits(takeProfit.toBigInt(), 8)}`);

    // bool limitOrder, bool executeLimitOrder, bool marketTrade,
    // bool userCloseTrade, bool tpSlCloseTrade, bool liquidateTradeSwitch,
    // bool predictBet, bool predictSettle

    // await execute(
    //     'RollDex', { from: deployer, log: true }, 'setTradingSwitches', true, true, true, 
    //     true, true, true, false, false
    // );

    const maxTakeProfits = await read('RollDex', 'getPairMaxTpRatios', pair.base);
    console.log("maxTakeProfits", maxTakeProfits);

    // const executionFeeReceiver = await read('RollDex', 'executionFeeReceiver');
    // console.log("executionFeeReceiver", executionFeeReceiver);

    // await execute('RollDex', {from: deployer, log: true}, 'setExecutionFeeReceiver', deployer);

    let rolldex = await get('RollDex');
    console.log("rolldex addr:", rolldex.address);
    const allowance = await read(tokenIn, 'allowance', deployer, rolldex.address);
    console.log("current allowance", ethers.formatUnits(allowance.toBigInt(), "ether"))
    if (allowance < ethers.parseEther(amountIn)) {
        console.log("adjust allowance", amountIn)
        await execute(tokenIn, {from: deployer, log: true}, 'approve', rolldex.address, ethers.parseEther(amountIn));
    }

    const marketOrderPrice  = (isLong ? price.mul(1002) : price.mul(999)).div(1000); 
    log(`market order, isLong: ${isLong}, price: ${ethers.formatUnits(marketOrderPrice.toBigInt(), 8)}`)
    /**
     *  
        address pairBase;
        bool isLong;
        // BUSD/USDT address
        address tokenIn;
        uint96 amountIn;   // tokenIn decimals
        uint80 qty;        // 1e10
        // Limit Order: limit price
        // Market Trade: worst price acceptable
        uint64 price;      // 1e8
        uint64 stopLoss;   // 1e8
        uint64 takeProfit; // 1e8
        uint24 broker;
     */
    console.log(deployer, token.address);

    let tx = await execute(
        'RollDex', {from: deployer, log: true, value: ethers.parseEther(amountIn)}, 'openMarketTradeNative', [
            pair.base, isLong, token.address, ethers.parseEther(amountIn), ethers.parseUnits("0.01", 10), marketOrderPrice, 0,
            takeProfit, 1
        ]
    );
    
    if (tx && tx.events) {
        // get last 2nd requestId
        const requestId = tx.events.slice(-2)[0].topics[1];
        console.log("requestId:", requestId)
        console.log("tradeHash:", tx.events.slice(-1)[0].args.tradeHash)

        await new Promise(r => setTimeout(r, 15*1000));

        // price callback
        await execute(
            'RollDex', {from: deployer, log: true}, 'requestPriceCallback', requestId, price
        );
    }

    
    log("26 openMarketTradeNative end".padStart(66, '.'));
    // struct OpenDataInput {
    //     // Pair.base
    //     address pairBase;
    //     bool isLong;
    //     // BUSD/USDT address
    //     address tokenIn;
    //     uint96 amountIn;   // tokenIn decimals
    //     uint80 qty;        // 1e10
    //     // Limit Order: limit price
    //     // Market Trade: worst price acceptable
    //     uint64 price;      // 1e8
    //     uint64 stopLoss;   // 1e8
    //     uint64 takeProfit; // 1e8
    //     uint24 broker;
    // }


    // console.log(pair.base, isLong, token.address, ethers.parseEther(amountIn), ethers.parseUnits("0.03", 10), orderPrice, 0,
    // takeProfit, 1);
    // // 0.03*68823= 2064
    // // balance: 2000
    // await execute(
    //     'RollDex', {from: deployer, log: true}, 'openLimitOrder', [
    //         pair.base, isLong, token.address, ethers.parseEther(amountIn), ethers.parseUnits("0.3", 10), orderPrice, 0,
    //         takeProfit, 1
    //     ]
    // );

    // log("21 openLimitOrder end".padStart(66, '.'));
}

module.exports.tags = ['26'];
module.exports.dependencies = [''];