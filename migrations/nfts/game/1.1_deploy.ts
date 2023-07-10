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
            "0x5FbDB2315678afecb367f032d93F642f64180aa3",
            "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
        );
        console.log("%s GenerativeProject address: %s", process.env.NETWORK, address);
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();