const { run } = require("hardhat");
const { AddressZero } = require('@ethersproject/constants');
const {
    getSelectors, intersectionSet, differenceSet, encodeDiamondCutCall, mergeABIs
} = require("./diamond_helpers");
/*
hardhat deploy --network bsc --tags 4
*/
/*
AccessControlEnumerableFacet、LpManagerFacet、TokenRewardFacet、BrokerManagerFacet、ChainlinkPriceFacet、DiamondCutFacet、
DiamondLoupeFacet、FeeManagerFacet、LimitOrderFacet、PairsManagerFacet、PausableFacet、PredictionManagerFacet、
PredictUpDownFacet、PriceFacadeFacet、SlippageManagerFacet、StakeRewardFacet、TimeLockFacet、TradingCheckerFacet、
TradingCloseFacet、TradingConfigFacet、TradingCoreFacet、TradingOpenFacet、TradingPortalFacet、TradingReaderFacet、
TransitionFacet、VaultFacet、
*/
const FacetCutAction = { Add: 0, Replace: 1, Remove: 2 }

const facetsToRemove = [];
const facetsToCut = [
    'AccessControlEnumerableFacet',
    'LpManagerFacet',
    'BrokerManagerFacet', 'ChainlinkPriceFacet',
    'FeeManagerFacet',
    'LimitOrderFacet',
    'PairsManagerFacet', 'PausableFacet',
    // 'PredictionManagerFacet',
    // 'PredictUpDownFacet',
    'PriceFacadeFacet',
    'SlippageManagerFacet',
    'TradingCheckerFacet', 'TradingCloseFacet',
    'TradingConfigFacet',
    'TradingCoreFacet',
    'TradingOpenFacet',
    'TradingPortalFacet', 'TradingReaderFacet', 'VaultFacet'
];
module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts }) {
    const { deploy, log, read, execute, getOrNull, get, save } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await getChainId();
    log("4 upgrade RollDex start".padEnd(66, '.'));

    let facetCuts = [];
    for (let i = 0; i < facetsToRemove; i++) {
        let facet = await get(facetsToRemove[i]);
        facetCuts.push({
            facetAddress: AddressZero,
            action: FacetCutAction.Remove,
            functionSelectors: getSelectors(facet.abi)
        });
    }
    let deployedFacets = [];
    let selectorsToAdd, selectorsToReplace, selectorsToRemove;
    for (const facet of facetsToCut) {
        const facetDeployment = await getOrNull(facet);
        let oldSelectors = await read(
            'RollDex', 'facetFunctionSelectors', facetDeployment ? facetDeployment.address : AddressZero
        );
        const deployedFacet = await deploy(facet, {
            from: deployer, log: true, skipIfAlreadyDeployed: false, deterministicDeployment: false, args: []
        });
        if (!deployedFacet.newlyDeployed) continue;
        deployedFacets.push(deployedFacet);
        let newSelectors = getSelectors(deployedFacet.abi);
        // Remove
        selectorsToRemove = differenceSet(oldSelectors, newSelectors);
        if (selectorsToRemove.length > 0) {
            facetCuts.push({
                facetAddress: AddressZero,
                action: FacetCutAction.Remove,
                functionSelectors: selectorsToRemove
            });
        }
        // Replace
        selectorsToReplace = intersectionSet(oldSelectors, newSelectors);
        if (selectorsToReplace.length > 0) {
            facetCuts.push({
                facetAddress: deployedFacet.address,
                action: FacetCutAction.Replace,
                functionSelectors: selectorsToReplace
            });
        }
        // Add
        selectorsToAdd = differenceSet(newSelectors, oldSelectors);
        if (selectorsToAdd.length > 0) {
            facetCuts.push({
                facetAddress: deployedFacet.address,
                action: FacetCutAction.Add,
                functionSelectors: selectorsToAdd
            });
        }
    }
    log("facetCuts: ", facetCuts);
    const rolldex = await get('RollDex');
    if (facetCuts.length > 0) {
        // const data = encodeDiamondCutCall(rolldex.abi, [facetCuts, AddressZero, '0x']).replace('0x1f931c1c', '0x');
        // log('data: ', data);
        await execute('RollDex', { from: deployer, log: true }, 'diamondCut', facetCuts, AddressZero, '0x');
    } else {
        log('No facetCuts have been updated or need to be removed.');
    }

    log("verify...");
    let allFacetAbi = [], changed = false;
    for (let i = 0; i < deployedFacets.length; i++) {
        const deployedFacet = deployedFacets[i];
        if (deployedFacet.newlyDeployed) {
            allFacetAbi = [...allFacetAbi, ...deployedFacet.abi];
            changed = true;
           // await run("verify:verify", { address: deployedFacet.address, constructorArguments: [] });
        }
    } 
    
    let combinedABI = mergeABIs(allFacetAbi, rolldex.abi);
    if (changed) {
        await save('RollDex', { ...rolldex, abi: combinedABI });
    }
    log("4 upgrade RollDex end".padStart(66, '.'));
};

module.exports.tags = ['4'];
module.exports.dependencies = [];