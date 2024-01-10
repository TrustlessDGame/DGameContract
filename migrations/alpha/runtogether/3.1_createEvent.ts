import * as dotenv from 'dotenv';

import {ethers} from "ethers";
import * as fs from "fs";
import {createAlchemyWeb3} from "@alch/alchemy-web3";
import {RunTogether} from "./RunTogether";
import dayjs = require("dayjs");
import Web3 from "web3";
import {DGameProject} from "../../nfts/game/DGameProject";

const hardhatConfig = require("../../../hardhat.config");

(async () => {
    try {
        if (process.env.NETWORK != "nos_testnet") {
            console.log("wrong network");
            return;
        }

        const nft = new RunTogether(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        const args = process.argv.slice(2)

        const contract = args[0];

        const tx = await nft.createEvent(
            contract,
            JSON.parse(JSON.stringify({
                        _name: "Event 1",
                        _desc: "",
                        _creatorAddr: process.env.PUBLIC_KEY,
                        _creator: "Alpha",
                        _image: "",
                    }
                )
            ), "0.001",
            0
        );
        console.log("tx:", tx?.transactionHash, tx?.status);
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();