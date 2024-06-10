const {getConfig} = require("./config");

/*
hardhat deploy --network bscTestnet --tags 25
*/
const tokenIn = 'BTC', pairName = 'BTC/USD', amountIn = '200';
module.exports = async function ({ethers, getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) {
    const {read, execute, get, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const config = getConfig(await getChainId());
    
    log("25 revenue start".padEnd(66, '.'));

    const token = config.tokens.filter(token => token.name === tokenIn)[0];
   
    const revenues = await read(
        'RollDex', {from: deployer, log: true}, 'revenues', [token.address]
    );

    // const brokerInfo = await read(
    //     'RollDex', {from: deployer, log: true}, 'getBrokerById', 0
    // );
    // console.log(brokerInfo);

    const brokerInfo = await read(
        'RollDex', {from: deployer, log: true}, 'brokers', 0, 3
    );
    console.log(brokerInfo);

    for (const broker of config.brokers) {
        const oldBroker = await read('RollDex', "getBrokerById", broker.id);
        console.log("oldBroker", oldBroker);

        for (const commission of oldBroker.commissions) {
            console.log("commission", commission.token, ethers.formatUnits(commission.total.toBigInt(), "ether"), 
                ethers.formatUnits(commission.pending.toBigInt(), "ether"));
        }

    //     if (!oldBroker.id) {
    //         await execute(
    //             'RollDex', {from: deployer, log: true}, 'addBroker',
    //             broker.id, broker.commissionP, broker.daoShareP, broker.lpPoolP,
    //             deployer, '', ''
    //         );
    //     } else {
    //         console.log('update');
    //         await execute(
    //             'RollDex', {from: deployer, log: true}, 'updateBrokerCommissionP',
    //             broker.id, broker.commissionP, broker.daoShareP, broker.lpPoolP
    //         );
    //     }
    }

    for (const rev of revenues) {
        console.log("rev token:", rev.token, ethers.formatUnits(rev.total.toBigInt(), "ether"))
    }

    // const feeDetails = await read(
    //     'RollDex', {from: deployer, log: true}, 'getFeeDetails', [token.address]
    // );   

    // for (const detail of feeDetails) {
    //     console.log("fee detail total",  ethers.formatUnits(detail.total.toBigInt(), "ether"))
    //     console.log("fee detail dao:",  ethers.formatUnits(detail.daoAmount.toBigInt(), "ether"))
    //     console.log("fee detail broker:",  ethers.formatUnits(detail.brokerAmount.toBigInt(), "ether"))
    //     console.log("fee detail lpPool:",  ethers.formatUnits(detail.lpPoolAmount.toBigInt(), "ether"))
    // }

    log("25 revenue end".padStart(66, '.'));
}

module.exports.tags = ['25'];
module.exports.dependencies = [''];