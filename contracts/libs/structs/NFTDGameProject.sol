// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library NFTDGameProject {
    struct DGameProject {
        string _name; // required
        string _desc; // not require
        string _image;// base64 of image

        string[] _scriptType;// not require
        string[] _scripts;// required
        string _styles;// not require

        string _creator;// required
        address _creatorAddr;// required
    }
}
