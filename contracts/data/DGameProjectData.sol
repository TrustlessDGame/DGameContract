pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "../interfaces/IParameterControl.sol";
import "../interfaces/IDGameProjectData.sol";
import "../interfaces/IDGameProject.sol";
import "../interfaces/IBFS.sol";

import "../libs/configs/DGameProjectConfigs.sol";
import "../libs/helpers/Inflate.sol";
import "../libs/helpers/Base64.sol";
import "../libs/structs/NFTDGameData.sol";
import "../libs/helpers/StringsUtils.sol";
import "../libs/helpers/Errors.sol";


contract DGameProjectData is OwnableUpgradeable, IDGameProjectData {
    address public _admin;
    address public _paramAddr;
    address public _gamesProjectAddr;
    address public _bfs;

    function initialize(address admin, address paramAddr, address gamesProjectAddr) initializer public {
        _admin = admin;
        _paramAddr = paramAddr;
        _gamesProjectAddr = gamesProjectAddr;
        __Ownable_init();
    }

    function changeAdmin(address newAdm) external {
        require(msg.sender == _admin && newAdm != address(0), Errors.ONLY_ADMIN_ALLOWED);

        // change admin
        if (_admin != newAdm) {
            _admin = newAdm;
        }
    }

    function changeParamAddress(address newAddr) external {
        require(msg.sender == _admin && newAddr != address(0), Errors.ONLY_ADMIN_ALLOWED);

        // change param address
        if (_paramAddr != newAddr) {
            _paramAddr = newAddr;
        }
    }

    function changeGamesProjectAddress(address newAddr) external {
        require(msg.sender == _admin && newAddr != address(0), Errors.ONLY_ADMIN_ALLOWED);

        // change Generative project address
        if (_gamesProjectAddr != newAddr) {
            _gamesProjectAddr = newAddr;
        }
    }

    function changeBfs(address newAddr) external {
        require(msg.sender == _admin && newAddr != address(0), Errors.ONLY_ADMIN_ALLOWED);

        if (_bfs != newAddr) {
            _bfs = newAddr;
        }
    }

    /* @GameDATA:
    */
    function gameURI(uint256 gameId) external view returns (string memory result) {
        NFTDGameData.DGameURIContext memory ctx;
        IDGameProject p = IDGameProject(_gamesProjectAddr);
        NFTDGameProject.DGameProject memory d = p.gameDetail(gameId);

        ctx._name = string(abi.encodePacked(d._name, " #", StringsUpgradeable.toString(gameId)));
        ctx._desc = d._desc;
        string memory inflate;
        Inflate.ErrorCode err;
        (inflate, err) = inflateString(ctx._desc);
        if (err == Inflate.ErrorCode.ERR_NONE) {
            ctx._desc = inflate;
        }
        ctx._image = d._image;
        ctx._creatorAddr = d._creatorAddr;
        ctx._creator = d._creator;
        string memory scriptType = "";
        for (uint8 i; i < d._scriptType.length; i++) {
            scriptType = string(abi.encodePacked(scriptType, ',{"trait_type": "Lib ', StringsUpgradeable.toString(i + 1), '", "value": "', d._scriptType[i], '"}'));
        }
        result = string(
            abi.encodePacked(
                '{"name":"', ctx._name, '"',
                ',"description":"', Base64.encode(abi.encodePacked(ctx._desc)), '"',
                ',"image":"', ctx._image, '"',
                '}'
            )
        );
    }

    function tokenHTML(uint256 gameId) external view returns (string memory result) {
        IDGameProject gamesProjectContract = IDGameProject(_gamesProjectAddr);
        NFTDGameProject.DGameProject memory gameProjectDetail = gamesProjectContract.gameDetail(gameId);
        string memory scripts = "";
        string memory inflate;
        Inflate.ErrorCode err;
        for (uint256 i = 1; i < gameProjectDetail._scripts.length; i++) {
            if (bytes(gameProjectDetail._scripts[i]).length > 0) {
                (inflate, err) = this.inflateString(gameProjectDetail._scripts[i]);
                if (err != Inflate.ErrorCode.ERR_NONE) {
                    scripts = string(abi.encodePacked(scripts, '<script>', gameProjectDetail._scripts[i], '</script>'));
                } else {
                    scripts = string(abi.encodePacked(scripts, '<script>', inflate, '</script>'));
                }
            }
        }
        scripts = string(abi.encodePacked(
                libsScript(gameProjectDetail._scriptType), // load libs here
                variableScript(gameId, gameProjectDetail), // load vars
                '<style>', gameProjectDetail._styles, '</style>', // load css
                '</head><body>',
                scripts, // load main code of user
                "</body>"
            ));
        result = scripts;
    }

    function libScript(string memory fileName) private view returns (string memory result){
        result = "<script sandbox='allow-scripts' type='text/javascript' preload='";
        result = string(abi.encodePacked(result, fileName, "'>"));
        result = string(abi.encodePacked(result, "</script>"));
    }

    function libsScript(string[] memory libs) public view returns (string memory scriptLibs) {
        scriptLibs = "";
        for (uint256 i = 0; i < libs.length; i++) {
            string memory lib = libScript(libs[i]);
            if (keccak256(abi.encodePacked(lib)) != keccak256(abi.encodePacked("ethersjs@5.7.2.js"))) {
                scriptLibs = string(abi.encodePacked(scriptLibs, lib));
            }
        }
    }

    function ethersjsLibScript(string memory fileName, uint256 chunkIndex) public view returns (bytes memory data, int256 nextChunkIndex) {
        IBFS bfs = IBFS(_bfs);
        if (bytes(fileName).length == 0) {
            fileName = "ethersjs@5.7.2.js";
        }
        address scriptProvider = IParameterControl(_paramAddr).getAddress("SCRIPT_PROVIDER");
        (data, nextChunkIndex) = bfs.load(scriptProvider, fileName, chunkIndex);
    }

    function variableScript(uint256 gameId, NFTDGameProject.DGameProject memory game) public view returns (string memory result) {
        result = '<script type="text/javascript" id="snippet-contract-code">';
        result = string(abi.encodePacked(result, "let GAME_ID='", StringsUpgradeable.toString(gameId), "';"));
        result = string(abi.encodePacked(result, "let GAME_CONTRACT_ADDRESS='", game._gameContract, "';"));
        result = string(abi.encodePacked(result, "let GAME_TOKEN_ERC20_ADDRESS='", game._gameTokenERC20, "';"));
        result = string(abi.encodePacked(result, "let GAME_NFT_ERC721_ADDRESS='", game._gameNFTERC721, "';"));
        result = string(abi.encodePacked(result, "let GAME_TOKEN_ERC1155_ADDRESS='", game._gameNFTERC1155, "';"));
        result = string(abi.encodePacked(result, "</script>"));
    }

    function inflateScript(string memory script) public view returns (string memory result, Inflate.ErrorCode err) {
        return inflateString(StringsUtils.getSlice(9, bytes(script).length - 9, script));
    }

    function inflateString(string memory data) public view returns (string memory result, Inflate.ErrorCode err) {
        return inflate(Base64.decode(data));
    }

    function inflate(bytes memory data) internal view returns (string memory result, Inflate.ErrorCode err) {
        bytes memory buff;
        (err, buff) = Inflate.puff(data, data.length * 20);
        if (err == Inflate.ErrorCode.ERR_NONE) {
            uint256 breakLen = 0;
            while (true) {
                if (buff[breakLen] == 0) {
                    break;
                }
                breakLen++;
                if (breakLen == buff.length) {
                    break;
                }
            }
            bytes memory temp = new bytes(breakLen);
            uint256 i = 0;
            while (i < breakLen) {
                temp[i] = buff[i];
                i++;
            }
            result = string(temp);
        } else {
            result = "";
        }
    }

    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
