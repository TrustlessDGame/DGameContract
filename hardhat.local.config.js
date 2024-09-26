require('dotenv/config');
require('@nomicfoundation/hardhat-toolbox');
require('@openzeppelin/hardhat-upgrades');
require('@nomicfoundation/hardhat-ethers');
require('@nomicfoundation/hardhat-chai-matchers');
require('@matterlabs/hardhat-zksync');

const LOCAL_RICH_WALLETS = [
    {
        address: "0xBC989fDe9e54cAd2aB4392Af6dF60f04873A033A",
        privateKey: "0x3d3cbc973389cb26f657686445bcc75662b415b656078503592ac8c1abb8810e",
        mnemonic: "mass wild lava ripple clog cabbage witness shell unable tribe rubber enter"
    },
    {
        address: "0x55bE1B079b53962746B2e86d12f158a41DF294A6",
        privateKey: "0x509ca2e9e6acf0ba086477910950125e698d4ea70fa6f63e000c5a22bda9361c",
        mnemonic: "crumble clutch mammal lecture lazy broken nominee visit gentle gather gym erupt"
    },
    {
        address: "0xCE9e6063674DC585F6F3c7eaBe82B9936143Ba6C",
        privateKey: "0x71781d3a358e7a65150e894264ccc594993fbc0ea12d69508a340bc1d4f5bfbc",
        mnemonic: "illegal okay stereo tattoo between alien road nuclear blind wolf champion regular"
    },
    {
        address: "0xd986b0cB0D1Ad4CCCF0C4947554003fC0Be548E9",
        privateKey: "0x379d31d4a7031ead87397f332aab69ef5cd843ba3898249ca1046633c0c7eefe",
        mnemonic: "point donor practice wear alien abandon frozen glow they practice raven shiver"
    },
    {
        address: "0x87d6ab9fE5Adef46228fB490810f0F5CB16D6d04",
        privateKey: "0x105de4e75fe465d075e1daae5647a02e3aad54b8d23cf1f70ba382b9f9bee839",
        mnemonic: "giraffe organ club limb install nest journey client chunk settle slush copy"
    },
    {
        address: "0x78cAD996530109838eb016619f5931a03250489A",
        privateKey: "0x7becc4a46e0c3b512d380ca73a4c868f790d1055a7698f38fb3ca2b2ac97efbb",
        mnemonic: "awful organ version habit giraffe amused wire table begin gym pistol clean"
    },
    {
        address: "0xc981b213603171963F81C687B9fC880d33CaeD16",
        privateKey: "0xe0415469c10f3b1142ce0262497fe5c7a0795f0cbfd466a6bfa31968d0f70841",
        mnemonic: "exotic someone fall kitten salute nerve chimney enlist pair display over inside"
    },
    {
        address: "0x42F3dc38Da81e984B92A95CBdAAA5fA2bd5cb1Ba",
        privateKey: "0x4d91647d0a8429ac4433c83254fb9625332693c848e578062fe96362f32bfe91",
        mnemonic: "catch tragic rib twelve buffalo also gorilla toward cost enforce artefact slab"
    },
    {
        address: "0x64F47EeD3dC749d13e49291d46Ea8378755fB6DF",
        privateKey: "0x41c9f9518aa07b50cb1c0cc160d45547f57638dd824a8d85b5eb3bf99ed2bdeb",
        mnemonic: "arrange price fragile dinner device general vital excite penalty monkey major faculty"
    },
    {
        address: "0xe2b8Cb53a43a56d4d2AB6131C81Bd76B86D3AFe5",
        privateKey: "0xb0680d66303a0163a19294f1ef8c95cd69a9d7902a4aca99c05f3e134e68a11a",
        mnemonic: "increase pulp sing wood guilt cement satoshi tiny forum nuclear sudden thank"
    }
];

const config = {
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {
            zksync: true,
        },
        localhost: {
            url: "http://localhost:8545",
            accounts: ['0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'],
            allowUnlimitedContractSize: true,
            gas: 30000000,
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
    },
    solidity: {
        compilers: [
          {
            version: "0.8.0",
            settings: {
              optimizer: {
                enabled: true,
                runs: 200,
              },
            },
          },
          {
            version: "0.8.12",  // You can include multiple versions if different contracts use different versions
            settings: {
              optimizer: {
                enabled: true,
                runs: 200,
              },
            },
          },
          {
            version: "0.8.20",  // Include a more recent version if needed
            settings: {
              optimizer: {
                enabled: true,
                runs: 200,
              },
            },
          },
        ],
      },
    paths: {
        sources: './contracts',
        tests: './test',
        cache: './cache',
        artifacts: './artifacts',
    },
    mocha: {
        timeout: 20000,
        color: true,
    },
};

module.exports = {
    config,
    LOCAL_RICH_WALLETS
};