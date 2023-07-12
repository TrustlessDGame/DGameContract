import * as dotenv from 'dotenv';

import {ethers} from "ethers";
import * as fs from "fs";
import {createAlchemyWeb3} from "@alch/alchemy-web3";
import {DGameProject} from "./DGameProject";
import dayjs = require("dayjs");

(async () => {
    try {
        if (process.env.NETWORK != "nos_testnet") {
            console.log("wrong network");
            return;
        }

        const nft = new DGameProject(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        const args = process.argv.slice(2)

        const contract = args[0];
        const tx = await nft.mint(
                contract,
                JSON.parse(JSON.stringify({
                    _name: "Test game",
                    _desc: "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
                    _image: "ipfs://QmZha95v86iME98rpxrJWbHerK3JjEHKkiGpdS4NgZKjdb",
                    _creator: "Dev team",
                    _creatorAddr: process.env.PUBLIC_KEY,
                    _scriptType: JSON.parse(JSON.stringify(["ethersumdjs@5.7.2.js.gz"])),
                    _scripts: ['let web3;function preload(){web3=new Web3(Web3.givenProvider),window.ethereum||alert("Please install metamask")}preload();', 'class WalletData{Wallet;Balance;constructor(){}async LoadWallet(){let t=localStorage.getItem("walletData");if(null==t){console.log("not exist wallet");let a=web3.eth.accounts.create(web3.utils.randomHex(32)),l=web3.eth.accounts.wallet.add(a),e=l.encrypt(web3.utils.randomHex(32));t={account:a,wallet:l,keystore:e},localStorage.setItem("walletData",JSON.stringify(t))}else console.log("exist wallet"),t=JSON.parse(t);this.Wallet=t,this.Balance=await web3.eth.getBalance(this.Wallet.account.address),console.log(this.Wallet.account.address,web3.utils.fromWei(this.Balance.toString()),"TC")}}let wallet=new WalletData;wallet.LoadWallet();'],
                    _styles: "",
                    _gameContract: "0xb537f09Ae5bF453fc881b25BCC8687f54ee70DB6",
                    _gameTokenERC20: "0x0000000000000000000000000000000000000000",
                    _gameNFTERC721: "0x0000000000000000000000000000000000000000",
                    _gameNFTERC1155: "0x0000000000000000000000000000000000000000",
                })),
                "0.001",
                0
            )
        ;
        console.log("tx:", tx?.transactionHash, tx?.status);
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();