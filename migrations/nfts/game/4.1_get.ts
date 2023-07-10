import * as dotenv from 'dotenv';

import {ethers} from "ethers";
import {DGameProject} from "./DGameProject";

(async () => {
    try {
        if (process.env.NETWORK != "nos_testnet") {
            console.log("wrong network");
            return;
        }
        const args = process.argv.slice(2);
        const contract = args[0];
        const nft = new DGameProject(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        let a: any = {};
        // a.getTokenURI = await nft.tokenURI(contract, args[1]);
        a.project = await nft.gameDetail(contract, args[1]);
        console.log(a.project);
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();