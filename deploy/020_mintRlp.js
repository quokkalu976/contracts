const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 20
*/
const tokenIn = 'USDT',  amountIn = '2';
module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {execute, get, read, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const config = getConfig(await getChainId());
    log("20 mintLP start".padEnd(66, '.'));

    let rolldex = await get('RollDex');
    const allowance = await read(tokenIn, 'allowance', deployer, rolldex.address);
    if (allowance < ethers.parseEther(amountIn)) {
        await execute(tokenIn, {from: deployer, log: true}, 'approve', rolldex.address, ethers.parseEther(amountIn));
    }

    const token = config.tokens.filter(token => token.name === tokenIn)[0];
    console.log(token);
    await execute(
        'RollDex', {from: deployer, log: true}, 'mintLP', token.address, ethers.parseEther(amountIn), 1, false
    );

    let lpPrice = await read('RollDex', 'lpPrice');
    console.log("lpPrice", BigInt(lpPrice).toString()); 
    

    let lpTokenSupply = await read('RLP', 'totalSupply');
    console.log("lpTokenSupply", BigInt(lpTokenSupply).toString()); 

    log("20 mintLP end".padStart(66, '.'));
}

module.exports.tags = ['20'];
module.exports.dependencies = [''];