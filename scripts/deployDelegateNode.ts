import {HardhatRuntimeEnvironment} from "hardhat/types";
import {deployOrUpgrade} from "./utils";

const archiveConstructor = ["0x0Aeb9DddE49632d59CE86a7d95334073ECE73Fdd", "0x0Aeb9DddE49632d59CE86a7d95334073ECE73Fdd"];

async function main (hre: HardhatRuntimeEnvironment) {
    console.log(`Deploying Delegate Node...`)
    const networkConfig = hre.network.config as any;
    try {
        const constructorArguments = [...archiveConstructor, process.env.WALLET_PUBLIC_KEY];
        const contract = await deployOrUpgrade(process.env.DELETEGATE_NODE_ADDRESS, 'DelegateNode', constructorArguments, networkConfig, true);
        if (!contract) {
            throw new Error(`Failed to deploy  Delegate Node`);
        }
    } catch (e) {
        console.log(e.message);
        throw e;
    }
    console.log(`Finish deploy Delegate Node-------`)
}

export default main;

// This ensures the script will execute the `main` function when run directly via `npx hardhat run`
if (require.main === module) {
    import("hardhat").then((hre) => {
        // @ts-ignore
        main(hre.default).catch((error) => {
            console.error(error);
            process.exitCode = 1;
        });
    });
}