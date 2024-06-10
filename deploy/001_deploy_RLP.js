const { run } = require("hardhat");
/*
hardhat deploy --network bscTestnet --tags 1
*/
module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts }) {
    const { deploy, get, log } = deployments;
    const { deployer } = await getNamedAccounts();
    await deploy('RLP', {
        from: deployer, args: [], log: true, skipIfAlreadyDeployed: true,
        proxy: {
            proxyContract: 'UUPS',
            execute: { methodName: 'initialize', args: [deployer], },
        }
    });

    log("verify...");
    const lpImpl = await get('RLP_Implementation');
    log("lpImpl: ", lpImpl.address);
    //await run("verify:verify", { address: lpImpl.address, constructorArguments: [] });
};

module.exports.tags = ['RLP', '1'];
module.exports.dependencies = [];