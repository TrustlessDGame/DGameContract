import * as dotenv from 'dotenv';
import {DGameProject} from "./DGameProject";


(async () => {
    try {
        if (process.env.NETWORK != "nos_testnet") {
            console.log("wrong network");
            return;
        }
        const nft = new DGameProject(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        const address = await nft.deployUpgradeable(
            "DGameWorld",
            "DGameWorld",
            process.env.PUBLIC_KEY,
            "0xB044122f1CD9080A60Da25b1A8d59162290D7275",
            "0xb537f09Ae5bF453fc881b25BCC8687f54ee70DB6",
            '0x158C0Ca719cd3a5e263f45e104C9B5f567039Df3'
        );
        console.log("%s DGameProject address: %s", process.env.NETWORK, address);
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();