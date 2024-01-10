import * as dotenv from 'dotenv';
import {RunTogether} from "./RunTogether";


(async () => {
    try {
        if (process.env.NETWORK != "nos_testnet") {
            console.log("wrong network");
            return;
        }
        const nft = new RunTogether(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        const address = await nft.deployUpgradeable(
            "RunTogether",
            "RunTogether",
            process.env.PUBLIC_KEY,
            "0xB044122f1CD9080A60Da25b1A8d59162290D7275",
        );
        console.log("%s DGameProject address: %s", process.env.NETWORK, address);
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();