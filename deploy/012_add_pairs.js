const {getConfig} = require("./config");
const {AddressZero, HashZero} = require('@ethersproject/constants');

/*
hardhat deploy --network bscTestnet --tags 12
*/

module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer, multisig} = await getNamedAccounts();
    const config = getConfig(await getChainId());

    log("12 add fee & slippage & pair start".padEnd(66, '.'));
    const {daoRepurchase, revenueAddress} = await read('RollDex', 'feeAddress');

    // if (daoRepurchase === AddressZero && revenueAddress === AddressZero) {
    //     // should change to multi-sig account
    //     await execute(
    //         'RollDex', {from: deployer, log: true}, 'initFeeManagerFacet', deployer, deployer
    //     );
    // }

    // for (const fc of config.fees) {
    //     const [fee, _] = await read('RollDex', "getFeeConfigByIndex", fc.id);
    //     if (!fee || !fee.enable) {
    //         await execute(
    //             'RollDex', {from: deployer, log: true}, 'addFeeConfig',
    //             fc.id, fc.name, fc.openFeeP, fc.closeFeeP, fc.shareP, fc.minCloseFeeP
    //         );
    //     }
    // }

    // for (const sc of config.slippages) {
    //     const [slippage, _] = await read('RollDex', "getSlippageConfigByIndex", sc.id);
    //     if (!slippage || !slippage.enable) {
    //         await execute(
    //             'RollDex', {from: deployer, log: true}, 'addSlippageConfig', sc.name, sc.id, sc.slippageConfig
    //         );
    //     }
    // }

    const pairView = await read('RollDex', "pairsV4");
    for (const pair of config.pairs
        .filter(pair => !pairView.some(pv => pv.base.toLowerCase() === pair.base.toLowerCase()))) {
        await execute(
            'RollDex', {from: deployer, log: true}, 'addPair', pair.base, pair.name, pair.pairType, pair.status,
            pair.pairConfig, pair.slippageIndex, pair.feeIndex, pair.leverageMargins, pair.longHoldingFeeRate,
            pair.shortHoldingFeeRate
        );
    }

    log("12 add fee & slippage & pair end".padStart(66, '.'));
}

module.exports.tags = ['pairs', '12'];
module.exports.dependencies = [];