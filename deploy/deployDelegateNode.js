const { deployOrUpgrade } = require("./utils");

const contractName = 'DelegateNode';

async function main(hre) {
    console.log(`Deploying Delegate Node...`);
    const networkConfig = hre.network.config;
    try {
        const constructorArguments = [
            process.env.ERC20_ADDRESS,
            process.env.ADMIN_ADDRESS,
            process.env.POOL_ADMIN_ADDRESS,
            process.env.MODERATOR_ADDRESS];
        const contract = await deployOrUpgrade(process.env.DELETEGATE_NODE_ADDRESS, contractName, constructorArguments, networkConfig, true);
        if (!contract) {
            throw new Error(`Failed to deploy Delegate Node`);
        }
    } catch (e) {
        console.log(e.message);
        throw e;
    }
    console.log(`Finish deploy Delegate Node-------`);
}

module.exports = main;

// This ensures the script will execute the `main` function when run directly via `npx hardhat run`
if (require.main === module) {
    require("hardhat").then((hre) => {
        main(hre).catch((error) => {
            console.error(error);
            process.exitCode = 1;
        });
    });
}