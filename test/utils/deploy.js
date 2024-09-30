const { Wallet } = require("zksync-ethers");
const { Deployer } = require("@matterlabs/hardhat-zksync");
const hre = require("hardhat");
const { zkUpgrades } = require("hardhat");
const { getProvider } = require("../../deploy/utils");

const getWallet = (privateKey) => {
    const provider = getProvider();
    return new Wallet(privateKey, provider);
}

const deployContract = async (wallet, contractArtifactName, constructorArguments = []) => {
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
    return contract;
};

const deployOrUpgradeZk = async (wallet, contractName, constructorParams = []) => {
    const deployer = new Deployer(hre, wallet);
    const artifact = await deployer.loadArtifact(contractName);
    try {
        let contract = await zkUpgrades.deployProxy(
            deployer.zkWallet, 
            artifact, 
            constructorParams, 
            { initializer: 'initialize' }, 
            true
        );
        await contract.waitForDeployment();
        return contract;
    } catch (e) {
        console.log("Deployment failed:", e);
    }
}

module.exports = {
    getWallet,
    deployContract,
    deployOrUpgradeZk
}