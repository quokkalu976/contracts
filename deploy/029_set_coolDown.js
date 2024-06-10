const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 29
*/

module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer, multisig} = await getNamedAccounts();
    const config = getConfig(await getChainId());

    log("29 cool down start".padEnd(66, '.'));

    await execute(
        'RollDex', { from: deployer, log: true }, 'setCoolingDuration', 10
    );

    const cdTime = await read('RollDex', 'coolingDuration');
    console.log("CD time(s)=", BigInt(cdTime).toString());

    log("29 cool down end".padStart(66, '.'));
}

module.exports.tags = ['cdCool', '29'];
module.exports.dependencies = [];