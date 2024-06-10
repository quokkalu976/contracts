const { getConfig } = require("./config");


/*
hardhat deploy --network bscTestnet --tags 22
*/
const tokenOut = 'USDT', alpToken = 'RLP', amountBurn = '2';
module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts }) {
    const { execute, get, read, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const config = getConfig(await getChainId());
    log("22 burnRlp start".padEnd(66, '.'));

    // approve ALP token
    let rolldex = await get('RollDex');
    const alpPrice = await read('RollDex', 'lpPrice');
    console.log("ALPPrice", BigInt(alpPrice).toString());


    

    const allowance = await read(alpToken, 'allowance', deployer, rolldex.address);
    console.log("allowance: ",  allowance, ", addr: ", rolldex.address);
    if (allowance < ethers.parseEther(amountBurn)) {
        console.log('start approve');
        await execute(alpToken, { from: deployer, log: true }, 'approve', rolldex.address, ethers.parseEther(amountBurn));
    }

    const token = config.tokens.filter(token => token.name === tokenOut)[0];
    console.log(deployer);
    await execute(
        'RollDex', { from: deployer, log: true }, 'burnLP', token.address, ethers.parseEther(amountBurn), 1, deployer
    );

    log("22 burnRlp end".padStart(66, '.'));
}

module.exports.tags = ['22'];
module.exports.dependencies = [''];