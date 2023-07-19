// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library NFTDGameProject {
    struct DGameProject {
        string _name; // required
        string _desc; // not require
        string _image;// base64 of image

        string[] _scriptType;// not require
        string[] _scripts;// required
        string[] _assets;// not required
        string[] _bfsAssetsKey; //not required
        string[] _bfsAssetsValue;//not required
        string _styles;// not required
        bytes32 _seed; // not required

        string _creator;// required
        address _creatorAddr;// required

        address _gameContract; // required
        address _gameTokenERC20; // optional
        address _gameNFTERC721; // optional
        address _gameNFTERC1155; // optional
    }
}
