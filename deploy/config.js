const { ethers } = require("ethers");
config = [
    {
        network: 'bitlayerTestnet',
        chainId: '200810',
        tokens: [{
            name: 'USDT', address: '0xab40fe1dae842b209599269b8dafb0c54a743438',
            priceFeed: '0x127DAf3e1DBB33E73bbdb9e7D73e64E9dddD9fF0',
            lpPool: {
                feeBasisPoints: 30, taxBasisPoints: 10, stable: true, dynamicFee: true, asMargin: true, asBet: true,
                weights: [10000]
            }
        }, {
            name: 'USDC', address: '0x209ba92b5cc962673a30998ed7a223109d0be5e8',
            priceFeed: '0xbafC2D83D5944148317407D8C2DCD5882a5F9E5b',
            lpPool: {
                feeBasisPoints: 25, taxBasisPoints: 15, stable: true, dynamicFee: true, asMargin: true, asBet: true,
                weights: [5000, 5000]
            }
        }, {
            name: 'BTC', address: '0x3e57d6946f893314324C975AA9CEBBdF3232967E',
            priceFeed: '0x62d2c5dee038faebc3f6ec498fd2bbb3b0080b03',
            lpPool: {
                feeBasisPoints: 25, taxBasisPoints: 45, stable: false, dynamicFee: true, asMargin: true, asBet: true, 
                weights: [4500, 3000, 2500]
            }
        }, {
            name: 'ETH', address: '0xea9a6a7795d43c0a0690d4fe33a8282df90d798f',
            priceFeed: '0x0523695eF598862BEb6425E595E4c6E7714048eC'
        }],
        
        brokers: [
            { id: 1, name: 'Broker', url: 'https://www.rolldex.io', commissionP: 5000, daoShareP: 0, lpPoolP: 0}
        ],
        fees: [
            { id: 1, name: 'degen fee rate group', openFeeP: 0, closeFeeP: 0, shareP: 15000, minCloseFeeP: 30 }
        ],
        slippages: [{
            id: 0, name: '0.02% fixed slippage', slippageConfig: {
                onePercentDepthAboveUsd: 0, onePercentDepthBelowUsd: 0,
                slippageLongP: 2, slippageShortP: 2, longThresholdUsd: 0, shortThresholdUsd: 0, slippageType: 0
            }
        }],
        pairs: [{
            name: 'BTC/USD', base: '0x3e57d6946f893314324C975AA9CEBBdF3232967E', pairType: 0, status: 0,
            slippageIndex: 0, feeIndex: 0, longHoldingFeeRate: 9500, shortHoldingFeeRate: 9500,
            pairConfig: {
                maxLongOiUsd: ethers.parseEther('2000000'), maxShortOiUsd: ethers.parseEther('2000000'),
                fundingFeePerBlockP: 271328006088, minFundingFeeR: 10000000000, maxFundingFeeR: 1140000000000
            },
            leverageMargins: [{
                notionalUsd: ethers.parseEther('1000000'), tier: 1, maxLeverage: 250,
                initialLostP: 8500, liqLostP: 9000
            }]
        }, {
            name: 'ETH/USD', base: '0xea9a6a7795d43c0a0690d4fe33a8282df90d798f', pairType: 0, status: 0,
            slippageIndex: 0, feeIndex: 0, longHoldingFeeRate: 9500, shortHoldingFeeRate: 9500,
            pairConfig: {
                maxLongOiUsd: ethers.parseEther('2000000'), maxShortOiUsd: ethers.parseEther('2000000'),
                fundingFeePerBlockP: 271328006088, minFundingFeeR: 10000000000, maxFundingFeeR: 1140000000000
            },
            leverageMargins: [{
                notionalUsd: ethers.parseEther('1000000'), tier: 1, maxLeverage: 250,
                initialLostP: 8500, liqLostP: 9000
            }]
        }],
        predictionPairs: []
    }
]

function getConfig(chainId) {
    return config.filter(cfg => cfg.chainId === chainId)[0];
}

exports.getConfig = getConfig;