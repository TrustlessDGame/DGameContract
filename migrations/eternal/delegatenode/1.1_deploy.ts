import * as dotenv from 'dotenv';
import {DelegateNode} from "./DelegateNode";


(async () => {
    try {
        if (process.env.NETWORK != "eai_testnet") {
            console.log("wrong network");
            return;
        }
        const nft = new DelegateNode(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        const address = await nft.deployUpgradeable(
            process.env.PUBLIC_KEY
        );

        console.log("%s DelegateNode address: %s", process.env.NETWORK, address);
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();
