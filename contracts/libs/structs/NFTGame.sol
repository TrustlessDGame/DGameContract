// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library NFTGame {
    struct Game {
        string _name; // required
        string _creator;// required
        string _desc; // not require
        string _image;// base64 of image
    }
}
