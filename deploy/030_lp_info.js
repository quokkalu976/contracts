const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 30
*/
const pairName = 'BTC/USD';
module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer, multisig} = await getNamedAccounts();
    const config = getConfig(await getChainId());

    log("29 lp info start".padEnd(66, '.'));

    const lpUPNLUSD = await read('RollDex', 'lpUnrealizedPnlTotalUsd');
    console.log("lpUnrealizedPnlTotalUsd=", ethers.formatUnits(lpUPNLUSD.toBigInt(), 18));
    
    const lpNotionalUsd = await read('RollDex', 'lpNotionalUsd');
    console.log("lpNotionalUsd=", ethers.formatUnits(lpNotionalUsd.toBigInt(), 18));

    // const lpUnrealizedPnlUsd = await read('RollDex', 'lpUnrealizedPnlUsd', "0x3e57d6946f893314324C975AA9CEBBdF3232967E");
    // console.log("lpUnrealizedPnlUsd=", lpUnrealizedPnlUsd);
    const pair = config.pairs.filter(p => p.name === pairName)[0];

    const getPairQty = await read('RollDex', 'getPairQty', pair.base);
    console.log("getPairQty, longQty=", ethers.formatUnits(getPairQty.longQty.toBigInt(), 10), ", shortQty=",
    ethers.formatUnits(getPairQty.shortQty.toBigInt(), 10));

    const lastLongAccFundingFeePerShare = await read('RollDex', 'lastLongAccFundingFeePerShare', pair.base);
    console.log("lastLongAccFundingFeePerShare=", ethers.formatUnits(lastLongAccFundingFeePerShare.toBigInt(), 18));

    

    log("30 lp info end".padStart(66, '.'));
}

module.exports.tags = ['lpInfo', '30'];
module.exports.dependencies = [];