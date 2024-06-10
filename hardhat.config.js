require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require("@nomicfoundation/hardhat-verify");
require('hardhat-deploy');
require('dotenv')
const fs = require("fs");

const key = fs.readFileSync(".key").toString().trim();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.19",
        settings: {
            optimizer: {
                enabled: true,
                runs: 1000
            }
        }
    },
    namedAccounts: {
        deployer: {
            default: 0,
            1: '',
        },
        keeper: '',
        predictionKeeper: '',
        oracle: '',
    },
    networks: {
        merlinTestnet: {
            url: "https://testnet-rpc.merlinchain.io",
            accounts: [key]
        },
        bitlayerTestnet: {
            url: "https://testnet-rpc.bitlayer-rpc.com" || "",
            accounts: [key]
        },
    },
    sourcify: {
        enabled: true
    },
    etherscan: {
        // npx hardhat verify --network sepolia <address> <Constructor argument>
        apiKey: {
            // npx hardhat verify --list-networks
            bitlayerTestnet: "1234",
            bitlayer: "1234"
        },
        // https://hardhat.org/verify-custom-networks
        customChains: [
            {
                network: "merlinTestnet",
                chainId: 686868,
                urls: {
                apiURL: "https://testnet-rpc.merlinchain.io",
                browserURL: "https://testnet-scan.merlinchain.io"
                }
            },
            {
              network: "bitlayerTestnet",
              chainId: 200810,
              urls: {
                apiURL: "https://api-testnet.btrscan.com/scan/api",
                browserURL: "https://testnet.btrscan.com/"
              }
            },
            {
              network: "bitlayer",
              chainId: 200901,
              urls: {
                apiURL: "https://api.btrscan.com/scan/api",
                browserURL: "https://www.btrscan.com/"
              }
            }
          ]
    }
};