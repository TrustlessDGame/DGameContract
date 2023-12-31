import * as fs from "fs";
import {Bfs} from "./bfs";
import pako from "pako";


function sleep(ms: number) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}

function getByteArray(filePath: string) {
    return fs.readFileSync(filePath);
}

(async () => {
    try {
        if (process.env.NETWORK !== "nos_testnet") {
            console.log("wrong network");
            return;
        }
        const data = new Bfs(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        const args = process.argv.slice(2)
        const file = args[1]
        const path = args[2]

        if (path.trim().length == 0) {
            console.log("Miss path")
            return
        }

        const fileName = file.split("/")[file.split("/").length - 1];
        let rawdata = getByteArray(file);

        console.log('rawdata', rawdata.length)
        const compressedData = pako.gzip(rawdata);

        // gzip
        const base64CompressedData = Buffer.from(compressedData).toString('base64');
        const dataURL = `data:@file/gzip;base64,${base64CompressedData}`;
        console.log(dataURL)
        rawdata = Buffer.from(dataURL)

        // partition rawdata into chunks
        const chunksize = 40_000;// max size
        let chunks = [];
        for (let i = 0; i < rawdata.length; i += chunksize) {
            const temp = rawdata.slice(i, i + chunksize)
            chunks.push(temp);
            console.log("chunk - ", temp)
        }
        console.log("Split to ", chunks.length);
        for (let i = 0; i < chunks.length; i++) {
            try {
                const filePath = [path, fileName, 'gzip'].join("-")
                console.log('inscribe chunk', i, 'of file path', filePath, 'with', chunks[i].length, 'bytes');
                const tx = await data.store(args[0], filePath, i, chunks[i], 29900000);// max gas limit
                console.log("tx:", tx?.transactionHash, tx?.status);
            } catch (e) {
                console.log("Error: ", e);
                break;
            }
        }
        console.log(['bfs:/', '42070', args[0], process.env.PUBLIC_KEY, path, fileName, 'gzip'].join("-"))

    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();