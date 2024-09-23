const { Provider, Wallet } = require("zksync-ethers");
const { Deployer } = require("@matterlabs/hardhat-zksync");
const { ethers } = require("ethers");
const { upgrades, zkUpgrades } = require("hardhat");
const hre = require("hardhat");
const dotenv = require("dotenv");

require('@nomiclabs/hardhat-ethers');
require("@openzeppelin/hardhat-upgrades");
require("@matterlabs/hardhat-zksync-node/dist/type-extensions");
require("@matterlabs/hardhat-zksync-verify/dist/src/type-extensions");

dotenv.config();

const deployOrUpgrade = async (address, contractName, constructorParams, networkConfig, isInitializable) => {
    console.log(networkConfig);
    if (networkConfig.url.includes('localhost')) {
        return deployOrUpgradeLocal(address, contractName, constructorParams, isInitializable);
    } else {
        return deployOrUpgradeZk(getMasterWallet(), address, contractName, constructorParams, isInitializable);
    }
};

async function deployOrUpgradeZk(wallet, address, contractName, constructorParams, isInitializable) {
    const deployer = new Deployer(hre, wallet);
    const artifact = await deployer.loadArtifact(contractName);
    console.log(constructorParams);

    if (address) {
        // Upgrade existing contract
        try {
            let contract = await zkUpgrades.upgradeProxy(deployer.zkWallet, address, artifact);
            await contract.deployed();
            console.log(`${contractName} contract is upgraded to ${address}`);
            return contract;
        } catch (e) {
            console.log("Upgrade failed:", e);
        }
    } else {
        // Deploy new contract
        try {
            const options = isInitializable ? { initializer: 'initialize' } : {};
            let contract = await zkUpgrades.deployProxy(deployer.zkWallet, artifact, constructorParams, options);
            await contract.deployed();
            const deployedAddress = contract.address;
            console.log(`${contractName} contract is deployed to ${deployedAddress}`);
            return contract;
        } catch (e) {
            console.log("Deployment failed:", e);
        }
    }

    throw new Error("Contract deployment or upgrade failed");
}

async function deployOrUpgradeLocal(address, contractName, constructorParams, isInitializable) {
    const contractFactory = await hre.ethers.getContractFactory(contractName);
    return address
        ? await (async () => {
            var contract = await upgrades.upgradeProxy(address, contractFactory);
            await contract.deployed();
            console.log(`${contractName} contract is upgraded to ${address}`);
            return contract;
        })()
        : await (async () => {
            const options = isInitializable ? { initializer: 'initialize' } : {};
            var contract = await upgrades.deployProxy(contractFactory, constructorParams, options);
            await contract.deployed();
            console.log(`${contractName} contract is deployed to ${contract.address}`);
            return contract;
        })();
}

const deployContract = async (contractArtifactName, constructorArguments = [], options = {}) => {
    const log = (message) => {
        if (!options.silent) console.log(message);
    };

    log(`\nStarting deployment process of "${contractArtifactName}"...`);

    const wallet = options.wallet ?? getMasterWallet();
    const deployer = new Deployer(hre, wallet);
    const artifact = await deployer.loadArtifact(contractArtifactName).catch((error) => {
        if (error?.message?.includes(`Artifact for contract "${contractArtifactName}" not found.`)) {
            console.error(error.message);
            throw new Error(`⛔️ Please make sure you have compiled your contracts or specified the correct contract name!`);
        } else {
            throw error;
        }
    });

    // Deploy the contract to zkSync
    const contract = await deployer.deploy(artifact, constructorArguments);

    const constructorArgs = contract.interface.encodeDeploy(constructorArguments);
    const fullContractSource = `${artifact.sourceName}:${artifact.contractName}`;

    // Display contract deployment info
    log(`\n"${artifact.contractName}" was successfully deployed:`);
    log(` - Contract address: ${contract.address}`);
    log(` - Contract source: ${fullContractSource}`);
    log(` - Encoded constructor arguments: ${constructorArgs}\n`);

    return contract;
};

const deployContractUpgradable = async (contractArtifactName, wallet, constructorArguments = []) => {
    console.log('a', getProvider());
    const contractFactory = await hre.ethers.getContractFactory(contractArtifactName);
    console.log('b', contractArtifactName);
    const options = { initializer: 'initialize' };
    console.log('c', contractFactory);
    console.log(constructorArguments);
    const contract = await upgrades.deployProxy(contractFactory, constructorArguments, options);
    console.log('d');
    await contract.deployed();
    console.log('e');
    return contract;
};

const getProvider = () => {
    const rpcUrl = hre.network.config.url;
    if (!rpcUrl) throw new Error(`⛔️ RPC URL wasn't found in "${hre.network.name}"! Please add a "url" field to the network config in hardhat.config.ts`);

    // Initialize zkSync Provider
    const provider = new Provider(rpcUrl);

    return provider;
};

const getMasterWallet = () => {
    const provider = getProvider();
    console.log(provider);
    return new Wallet(hre.network.config.accounts[0] ?? process.env.WALLET_PRIVATE_KEY, provider);
};

const getContract = async (adminWallet, contractName, address) => {
    const networkConfig = hre.network.config;
    if (networkConfig.url.includes('localhost')) {
        const ContractFactory = await hre.ethers.getContractFactory(contractName);
        return ContractFactory.attach(address);
    } else {
        const Artifact = await hre.artifacts.readArtifact(contractName);
        return new ethers.Contract(
            address,
            Artifact.abi,
            adminWallet
        );
    }
};

module.exports = {
    deployOrUpgrade,
    deployOrUpgradeZk,
    deployOrUpgradeLocal,
    deployContract,
    deployContractUpgradable,
    getProvider,
    getMasterWallet,
    getContract
};