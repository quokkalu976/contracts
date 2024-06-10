# RollDex 

RLP: Liquidity Provider token

RollDex: Main Contract

## Deploy Testnet
```
- rm -rf node_modules
- yarn install
- npx hardhat clean
- npx hardhat compile
- npx hardhat deploy --network bitlayerTestnet --tags 1,3,4
//,6,7,8,9,10,11,12,13,14
```
- Only prod, Make sure you put deployer's private key in .key file
- After RollDex deployed: "address"in the json file
- If want to update/remove some Facets，comment in deploy files #4
- verify takes time，can comment out verify:verify to speed up the deployment
- after modification, npx hardhat deploy --network bitlayerTestnet --tags 4
- deployments/xxxTestnet/USDT.json|.chainId can be kept

## How to add one test token
	1.	Issue an ERC20 USDT
	2.	Replace config.js -> tokens -> name: 'USDT'
    3.  Add oracle priceFeed, npx hardhat deploy --network bscTestnet --tags 7, Need to remove the previous feed
	4.  Call VaultFacet tokenV3() to verify
	5.	read('RollDex', 'chainlinkPriceFeeds')

## Approve allowance
```
const tokenIn = 'USDT';
const {execute, get, read, log} = deployments;
let rlp = await get('RLP');
const allowance = await read(tokenIn, 'allowance', deployer, rlp.address);
if (allowance < ethers.parseEther(amountIn)) {
	await execute(tokenIn, {from: deployer, log: true}, 'approve', rlp.address, ethers.parseEther(amountIn));
}
- Place Order: openMarketTrade -> priceCallback to settle

```


## Place Orders
facets: Implementation
interfaces: Interfaces
libraries: Storage

### Slippage(Acceptable Price)：
sc.slippageType = FIXED(Default), ONE_PERCENT_DEPTH, NET_POSITION, THRESHOLD

#0，0.01% slippage
#1，

pair.slippageIndex = #0

await execute(
    'RollDex', {from: deployer, log: true}, 'addSlippageConfig', sc.name, sc.id, sc.slippageConfig
);

await execute(
    'RollDex', {from: deployer, log: true}, 'addPair', pair.base, pair.name, pair.pairType, pair.status,
    pair.pairConfig, pair.slippageIndex, pair.feeIndex, pair.leverageMargins, pair.longHoldingFeeRate,
    pair.shortHoldingFeeRate
);

### Place LimitOrder
a. LimitOrderFacet -> openLimitOrder

	struct OpenDataInput {
        // Pair.base
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
    }

    await execute(
        'RollDex', {from: deployer, log: true}, 'openLimitOrder', [
            pair.base, isLong, token.address, ethers.parseEther(amountIn), ethers.parseUnits("0.3", 10), price, 0,
            takeProfit, 1
        ]
    );
b. ParamCheck -> ITradingChecker(address(this)).openLimitOrderCheck(data)

c. LimitOrderFacet->executeLimitOrder，keeper scan the market price and call
- executeLimitOrderCheck -> triggerPrice，stopPrice，maxOI，openLost
- ITradingOpen(address(this)).limitOrderDeal -> successful filled, openFee, updatePairPositionInfo
- sendEvent -> OpenMarketTrade
- _removeOrder
- executionFee (for keeper)， 
- tokenIn.transfer(ITradingConfig(address(this)).executionFeeReceiver(), executionFee);

d. Close Position TradingCloseFacet-》closeTradeCallback
- Collect fundingFee, holdingFee，closeFee(LibTrading.calcCloseFee), 
- Settle pnl
- _settleForCloseTrade
- _settleAsset, fee distribution
- _removeOpenTrade

