const {AddressZero, HashZero} = require("@ethersproject/constants");

/*
hardhat deploy --network bscTestnet --tags 8
*/

module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer} = await getNamedAccounts();

    log("8 init LP Manager start".padEnd(66, '.'));
    // Query LP Token and Bind to RollDex
    await read('RollDex', 'LP')
        .then(async (lp) => {
            if (lp === AddressZero) {
                const lpToken = await get('RLP');
                return execute('RollDex', {from: deployer, log: true}, 'initLpManagerFacet', lpToken.address);
            } else {
                log('initLpManagerFacet method has already been called');
            }
        });

    log("8 init LP Manager end".padStart(66, '.'));
}

module.exports.tags = ['8'];
module.exports.dependencies = [];