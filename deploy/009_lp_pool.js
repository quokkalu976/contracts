const {getConfig} = require("./config");
const {AddressZero, HashZero} = require("@ethersproject/constants");

/*
hardhat deploy --network bscTestnet --tags 9
*/

module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const config = getConfig(await getChainId());

    log("9 addToken start".padEnd(66, '.'));

    const tokens = await read('RollDex', 'tokensV3');
    console.log("Supported Collaterals:", tokens);
    // await execute(
    //     'RollDex', {from: deployer, log: true}, 'removeToken', 
    //     "0x31264bfa70d9db2cf8b495a1ea70d03d7e630bb7", [5000, 5000, 0]
    // );
    // if (tokens && tokens.length > 0) {
    //     for (const token of tokens) {
    //         console.log("Remove supported token from vault: ", token.tokenAddress)
    //         await execute(
    //             'RollDex', {from: deployer, log: true}, 'removeToken', 
    //             "0x31264bfa70d9db2cf8b495a1ea70d03d7e630bb7", [5000,5000,0]
    //         );
    //         break;
    //     }
    // }

    if (!tokens || !tokens.length) {
        for (const poolToken of config.tokens.filter(token => token.lpPool)) {
            console.log(poolToken);

            // await execute(
            //     'RollDex', {from: deployer, log: true}, 'addToken', 
            //     poolToken.address, 0,
            //     0, false, 
            //     0, false, false, []
            // );

            const lpPool = poolToken.lpPool;
            // TODO: add description for each field
            await execute(
                'RollDex', {from: deployer, log: true}, 'addToken', 
                poolToken.address, lpPool.feeBasisPoints,
                lpPool.taxBasisPoints, lpPool.stable, 
                lpPool.dynamicFee, lpPool.asMargin, lpPool.asBet, lpPool.weights
            );
        }
        
    }

    log("9 addToken end".padStart(66, '.'));
}

module.exports.tags = ['9'];
module.exports.dependencies = [];