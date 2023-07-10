import * as dotenv from 'dotenv';
import {DGameProjectData} from "./DGameProjectData";


(async () => {
    try {
        if (process.env.NETWORK != "nos_testnet") {
            console.log("wrong network");
            return;
        }
        const nft = new DGameProjectData(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        const address = await nft.deployUpgradeable(
            process.env.PUBLIC_KEY,
            "0xB044122f1CD9080A60Da25b1A8d59162290D7275",
            "0xCace1b78160AE76398F486c8a18044da0d66d86D",
        );
        console.log("%s GenerativeProjectData address: %s", process.env.NETWORK, address);
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();