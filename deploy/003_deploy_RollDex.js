const { run } = require("hardhat");
const { mergeABIs } = require("./diamond_helpers");
/*
hardhat deploy --network bscTestnet --tags 3
*/
module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts }) {
    const { deploy, log, save } = deployments;
    const { deployer } = await getNamedAccounts();
    log("3 deploy RollDex start".padEnd(66, '.'));

    const diamondCutFacet = await deploy('DiamondCutFacet', {
        from: deployer, log: true, skipIfAlreadyDeployed: true, deterministicDeployment: false, args: []
    });

    const diamondLoupeFacet = await deploy('DiamondLoupeFacet', {
        from: deployer, log: true, skipIfAlreadyDeployed: true, deterministicDeployment: false, args: []
    });

    const rollDexInit = await deploy('RollDexInit', {
        from: deployer, log: true, skipIfAlreadyDeployed: true, deterministicDeployment: false, args: []
    });

    const args = [deployer, deployer, diamondCutFacet.address, diamondLoupeFacet.address, rollDexInit.address];
    const rolldex = await deploy('RollDex', {
        from: deployer, log: true, deterministicDeployment: false,
        args: args
    });
    log(`RollDex deployed: ${rolldex.address}`);

    let combinedABI = mergeABIs([...diamondCutFacet.abi, ...diamondLoupeFacet.abi], rolldex.abi);
    await save('RollDex', { ...rolldex, abi: combinedABI });

    log("verify...");
    if (diamondCutFacet.newlyDeployed) {
        // await run("verify:verify", { address: diamondCutFacet.address, constructorArguments: [] });
    }
    if (diamondLoupeFacet.newlyDeployed) {
        // await run("verify:verify", { address: diamondLoupeFacet.address, constructorArguments: [] });
    }
    // hardhat verify --network bscTestnet <address>
    // if (rolldex.newlyDeployed) {
    //     await run("verify:verify", {address: rolldex.address, constructorArguments: args});
    // }
    if (rollDexInit.newlyDeployed) {
        // await run("verify:verify", { address: rollDexInit.address, constructorArguments: [] });
    }
    log("3 deploy RollDex end".padStart(66, "."));
};

module.exports.tags = ['RollDex', '3'];
module.exports.dependencies = [];