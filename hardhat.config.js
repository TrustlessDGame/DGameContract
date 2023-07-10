/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require("dotenv").config();
require("@nomiclabs/hardhat-ethers");
require("hardhat-gas-reporter");
require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
var verify = require("@ericxstone/hardhat-blockscout-verify");

module.exports = {
    solidity: {
        version: "0.8.12",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    defaultNetwork: process.env.NETWORK,
    etherscan: {
        apiKey: process.env.ETHSCAN_API_KEY,
        customChains: [
            {
                network: "tc_mainnet",
                chainId: 22213,
                urls: {
                    apiURL: "https://explorer.trustless.computer/api",
                    browserURL: "https://explorer.trustless.computer/api"
                }
            },
            {
                network: "tc_testnet",
                chainId: 22215,
                urls: {
                    apiURL: "https://explorer.regtest.trustless.computer/api",
                    browserURL: "https://explorer.regtest.trustless.computer/api"
                }
            }
        ]
    },
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
        },
        local: {
            url: process.env.LOCAL_API_URL,
            accounts: [
                `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`,
            ],
        },
        nos_testnet: {
            url: process.env.NOS_TESTNET_API_URL,
            accounts: [`0x${process.env.PRIVATE_KEY}`],
        },
        nos_mainnet: {
            url: process.env.NOS_MAINNET_API_URL,
            accounts: [`0x${process.env.PRIVATE_KEY}`],
            timeout: 100_000,
        }
    },
    mocha: {
        timeout: 40000000,
    }
};