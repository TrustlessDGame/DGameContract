require("dotenv").config();
require("@matterlabs/hardhat-zksync");
require('@nomicfoundation/hardhat-ethers');
require('@nomicfoundation/hardhat-chai-matchers');

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  defaultNetwork: process.env.NETWORK,
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      zksync:true,
    },
    zkSyncSepoliaTestnet: {
      url: "https://sepolia.era.zksync.dev",
      ethNetwork: "sepolia",
      zksync: true,
      verifyURL: "https://explorer.sepolia.era.zksync.dev/contract_verification",
    },
    zkSyncMainnet: {
      url: "https://mainnet.era.zksync.io",
      ethNetwork: "mainnet",
      zksync: true,
      verifyURL: "https://zksync2-mainnet-explorer.zksync.io/contract_verification",
    },
    localhost: {
        url: "http://localhost:8545",
        allowUnlimitedContractSize: true,
        mining: {
            auto: true,
            interval: 5000,
        },
    },
    dockerizedNode: {
        url: "http://localhost:3050",
        ethNetwork: "http://localhost:8545",
        zksync: true,
    },
    inMemoryNode: {
        url: "http://127.0.0.1:8011",
        ethNetwork: "localhost", // in-memory node doesn't support eth node; removing this line will cause an error
        zksync: true,
    },
    zkTestnet: {
      url: "https://rpc.testnet.supersonic2.bvm.network/",
      accounts: [process.env.WALLET_PRIVATE_KEY],
      chainId: 22219,
      allowUnlimitedContractSize: true,
      ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
      zksync: true, // Flag that targets zkSync Era.
    }
  },
  mocha: {
    timeout: 40000000,
  },
  zksolc: {
        version: "latest",
        settings: {
            // find all available options in the official documentation
            // https://era.zksync.io/docs/tools/hardhat/hardhat-zksync-solc.html#configuration
        },
    },
};
