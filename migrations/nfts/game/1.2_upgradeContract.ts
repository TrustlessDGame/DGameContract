import {DGameProject} from "./DGameProject";

(async () => {
    try {
        if (process.env.NETWORK != "nos_testnet") {
            console.log("wrong network");
            return;
        }
        const args = process.argv.slice(2);
        const nft = new DGameProject(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        const address = await nft.upgradeContract(args[0]);
        console.log({address});
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();