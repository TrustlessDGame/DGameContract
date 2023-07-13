import * as dotenv from 'dotenv';
import {RandomizerService} from "./randomizerService";


(async () => {
    try {
        if (process.env.NETWORK != "nos_testnet") {
            console.log("wrong network");
            return;
        }
        const nft = new RandomizerService(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        const args = process.argv.slice(2);
        const address = await nft.upgradeContract(args[0]);
        console.log("%s RandomizerService address: %s", process.env.NETWORK, address);
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();