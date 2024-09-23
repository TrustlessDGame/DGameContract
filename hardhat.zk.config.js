require("dotenv").config();
require("@matterlabs/hardhat-zksync");

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
    dockerizedNode: {
      url: "http://localhost:3050",
      ethNetwork: "http://localhost:8545",
      zksync: true,
    },
    inMemoryNode: {
      url: "http://127.0.0.1:8011",
      ethNetwork: "localhost",
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
};
