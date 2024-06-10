const {accounts} = require("@openzeppelin/test-environment");

/*
hardhat deploy --network bscTestnet --tags 6
*/

const roles = {
    // RLP
    MINTER_ROLE: "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",

    // RollDex
    DEFAULT_ADMIN_ROLE: "0x0000000000000000000000000000000000000000000000000000000000000000",
    ADMIN_ROLE: "0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775",
    TOKEN_OPERATOR_ROLE: "0x62150a51582c26f4255242a3c4ca35fb04250e7315069523d650676aed01a56a",
    PRICE_FEED_OPERATOR_ROLE: "0xc24d2c87036c9189cc45e221d5dff8eaffb4966ee49ea36b4ffc88a2d85bf890",
    PAIR_OPERATOR_ROLE: "0x04fcf77d802b9769438bfcbfc6eae4865484c9853501897657f1d28c3f3c603e",
    KEEPER_ROLE: "0xfc8737ab85eb45125971625a9ebdb75cc78e01d5c1fa80c4c6e5203f47bc4fab",
    PREDICTION_KEEPER_ROLE: "0x4e89f34ce8e0125b1b19130806ace319a8a06b7e1b4d6ef98c0eac043b6f119a",
    PRICE_FEEDER_ROLE: "0x7d867aa9d791a9a4be418f90a2f248aa2c5f1348317792a6f6412f94df9819f7",
    MONITOR_ROLE: "0x8227712ef8ad39d0f26f06731ef0df8665eb7ada7f41b1ee089adf3c238862a2"
}
module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    // namedAccounts from hardhat.config.js
    const {deployer, keeper, predictionKeeper, oracle} = await getNamedAccounts();

    log("6 init permissions start".padEnd(66, "."));
    let rolldex = await get('RollDex');
    await grantRole('RLP', read, execute, deployer, roles.MINTER_ROLE, rolldex.address);
    await grantRole('RollDex', read, execute, deployer, roles.ADMIN_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.TOKEN_OPERATOR_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.PRICE_FEED_OPERATOR_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.PAIR_OPERATOR_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.KEEPER_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.PREDICTION_KEEPER_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.PRICE_FEEDER_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.MONITOR_ROLE, deployer);

    await grantRole('RollDex', read, execute, deployer, roles.DEFAULT_ADMIN_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.KEEPER_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.PREDICTION_KEEPER_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.PRICE_FEEDER_ROLE, deployer);
    await grantRole('RollDex', read, execute, deployer, roles.MONITOR_ROLE, deployer);

    // ----、
    // await grantRole('RollDex', read, execute, deployer, roles.PRICE_FEEDER_ROLE, "0xB2917A33d9a920ffbDeF0984e273C787EF25AB46");
    // await revokeRole('RollDex', read, execute, deployer, roles.PRICE_FEEDER_ROLE, "0xB2917A33d9a920ffbDeF0984e273C787EF25AB46");
    // ---
    // await grantRole('RollDex', read, execute, deployer, roles.KEEPER_ROLE, keeper);
    // await grantRole('RollDex', read, execute, deployer, roles.PREDICTION_KEEPER_ROLE, predictionKeeper);
    // await grantRole('RollDex', read, execute, deployer, roles.PRICE_FEEDER_ROLE, oracle);
    // await grantRole('RollDex', read, execute, deployer, roles.MONITOR_ROLE, keeper);

    log("6 init permissions start".padStart(66, "."));
};

async function grantRole(name, read, execute, deployer, role, account) {
    console.log(`Ready to set ${role} role on ${name} for ${account}`);
    await read(name, 'hasRole', role, account).then(hasRole => {
        if (!hasRole) {
            console.log('Roles being set up');
            return execute(name, {from: deployer, log: true}, 'grantRole', role, account);
        } else {
            console.log(`Already has role`);
        }
    });
}

async function revokeRole(name, read, execute, deployer, role, account) {
    console.log(`Ready to revoke ${role} role on ${name} for ${account}`);
    const count = await read(name, 'getRoleMemberCount', role);
    console.log(count);
    for (let i = 0; i < count; i++) {
        const roleAddress = await read(name, 'getRoleMember', role, i);
        console.log(roleAddress);
    }

    await read(name, 'hasRole', role, account).then(hasRole => {
        if (hasRole) {
            return execute(name, {from: deployer, log: true}, 'revokeRole', role, account);
        } else {
            console.log(`Has no role`);
        }
    });
}

module.exports.tags = ['init_permissions', '6'];
module.exports.dependencies = [];