pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "../interfaces/IParameterControl.sol";
import "../interfaces/IDGameProjectData.sol";
import "../interfaces/IDGameProject.sol";
import "../interfaces/IBFS.sol";

import "../libs/configs/DGameProjectConfigs.sol";
import "../libs/configs/DGameProjectDataConfigs.sol";
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

        ctx._name = d._name;
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
        result = string(
            abi.encodePacked(
                '{"name":"', ctx._name, '"',
                ',"description":"', Base64.encode(abi.encodePacked(ctx._desc)), '"',
                ',"image":"', ctx._image, '"',
                '}'
            )
        );
    }

    function gameHTML(uint256 gameId) external view returns (string memory result) {
        IDGameProject gamesProjectContract = IDGameProject(_gamesProjectAddr);
        NFTDGameProject.DGameProject memory gameProjectDetail = gamesProjectContract.gameDetail(gameId);
        string memory scripts = "";
        string memory inflate;
        Inflate.ErrorCode err;
        for (uint256 i = 0; i < gameProjectDetail._scripts.length; i++) {
            if (bytes(gameProjectDetail._scripts[i]).length > 0) {
                (inflate, err) = this.inflateString(gameProjectDetail._scripts[i]);
                if (err != Inflate.ErrorCode.ERR_NONE) {
                    scripts = string(abi.encodePacked(scripts, '<script>', gameProjectDetail._scripts[i], '</script>'));
                } else {
                    scripts = string(abi.encodePacked(scripts, '<script>', inflate, '</script>'));
                }
            }
        }
        scripts = string(abi.encodePacked(scripts, loadPreloadScript()));
        scripts = string(abi.encodePacked(
                "<html>",
                "<head><meta charset='UTF-8'>",
                loadDecompressLib(), // load decompress lib
                loadABIJsonInterfaceBasic(), // load abi json interface: erc-20, erc-1155, erc-721, bfs
                libsScript(gameProjectDetail._scriptType), // load libs here
                variableScript(gameId, gameProjectDetail), // load vars
                loadContractInteractionBasic(), // wallet, bfs call asset, ...
                assetsScript(gameId, gameProjectDetail), // load assets
                loadInternalStyle(), // load internal style css
                '<style>', gameProjectDetail._styles, '</style>', // load css
                '</head><body>',
                scripts, // load main code of user
                "</body>",
                "</html>"
            ));
        result = scripts;
    }

    function loadInternalStyle() public view returns (string memory result) {
        result = '<link rel="stylesheet" name="INTERNAL_STYLE" type="text/css" href="data:text/css;base64,';
        string memory temp = IParameterControl(_paramAddr).get(DGameProjectDataConfigs.INTERNAL_STYLE);
        if (bytes(temp).length > 0) {
            result = string(abi.encodePacked(result, temp));
        } else {
            require(1 == 0, Errors.INV_DECOMPRESS_SCRIPT);
        }
        result = string(abi.encodePacked(result, '"/>'));
    }

    function loadPreloadScript() public view returns (string memory result) {
        // run preload script
        result = "<script sandbox='allow-scripts' type='text/javascript' name='PRELOAD_SCRIPT' src='data:@file/javascript;base64,";
        string memory temp = IParameterControl(_paramAddr).get(DGameProjectDataConfigs.PRELOAD_SCRIPT);
        if (bytes(temp).length > 0) {
            result = string(abi.encodePacked(result, temp));
        } else {
            require(1 == 0, Errors.INV_DECOMPRESS_SCRIPT);
        }
        result = string(abi.encodePacked(result, "'></script>"));
    }

    function loadABIJsonInterfaceBasic() public view returns (string memory result) {
        result = "<script sandbox='allow-scripts' type='text/javascript' name='ABI_JSON_BASIC' src='data:@file/javascript;base64,";
        string memory temp = IParameterControl(_paramAddr).get(DGameProjectDataConfigs.ABI_JSON_BASIC);
        if (bytes(temp).length > 0) {
            result = string(abi.encodePacked(result, temp));
        } else {
            require(1 == 0, Errors.INV_DECOMPRESS_SCRIPT);
        }
        result = string(abi.encodePacked(result, "'></script>"));
    }

    function loadContractInteractionBasic() public view returns (string memory result) {
        result = "<script sandbox='allow-scripts' type='text/javascript' name='CONTRACT_INTERACTION_BASIC' src='data:@file/javascript;base64,";
        string memory temp = IParameterControl(_paramAddr).get(DGameProjectDataConfigs.CONTRACT_INTERACTION_BASIC);
        if (bytes(temp).length > 0) {
            result = string(abi.encodePacked(result, temp));
        } else {
            require(1 == 0, Errors.INV_DECOMPRESS_SCRIPT);
        }
        result = string(abi.encodePacked(result, "'></script>"));
    }

    function loadDecompressLib() public view returns (string memory result) {
        result = "<script sandbox='allow-scripts' type='text/javascript' name='DECOMPRESS_LIB' src='data:@file/javascript;base64,";
        string memory temp = IParameterControl(_paramAddr).get(DGameProjectDataConfigs.DECOMPRESS_LIB);
        if (bytes(temp).length > 0) {
            result = string(abi.encodePacked(result, temp));
        } else {
            require(1 == 0, Errors.INV_DECOMPRESS_SCRIPT);
        }
        result = string(abi.encodePacked(result, "'></script>"));
    }

    function loadLibFileContent(string memory fileName) internal view returns (string memory script) {
        script = "";
        IBFS bfs = IBFS(_bfs);
        // count file
        address scriptProvider = IParameterControl(_paramAddr).getAddress(DGameProjectDataConfigs.SCRIPT_PROVIDER);
        uint256 count = bfs.count(scriptProvider, fileName);
        count += 1;
        // load and concat string
        for (uint256 i = 0; i < count; i++) {
            (bytes memory data, int256 nextChunk) = bfs.load(scriptProvider, fileName, i);
            script = string(abi.encodePacked(script, string(data)));
        }

    }

    function libScript(string memory fileName) public view returns (string memory result){
        result = "<script sandbox='allow-scripts' type='text/javascript'>";
        string memory lib = string(abi.encodePacked("getGzipFile(dataURItoBlob('", loadLibFileContent(fileName), "'))"));
        result = string(abi.encodePacked(result, lib));
        result = string(abi.encodePacked(result, "</script>"));
    }

    function libsScript(string[] memory libs) private view returns (string memory scriptLibs) {
        scriptLibs = "";
        for (uint256 i = 0; i < libs.length; i++) {
            string memory lib = libScript(libs[i]);
            scriptLibs = string(abi.encodePacked(scriptLibs, lib));
        }
    }

    function assetsScript(uint256 gameId, NFTDGameProject.DGameProject memory game) public view returns (string memory result) {
        result = '<script type="text/javascript" id="snippet-contract-code">';
        result = string(abi.encodePacked(result, "const GAME_ASSETS={"));
        if (game._assets.length > 0) {
            for (uint256 i = 0; i < game._assets.length; i++) {
                result = string(abi.encodePacked(result, "'", game._assets[i],
                    "':'bfs://",
                    StringsUpgradeable.toString(getChainID()), "/",
                    StringsUpgradeable.toHexString(game._creatorAddr), "/",
                    game._assets[i],
                    "',"));
            }
        }
        if (game._bfsAssetsKey.length > 0) {
            for (uint256 i = 0; i < game._bfsAssetsKey.length; i++) {
                result = string(abi.encodePacked(result, "'", game._bfsAssetsKey[i],
                    "':'", game._bfsAssetsValue[i],
                    "',"));
            }
        }
        result = string(abi.encodePacked(result, "};"));
        result = string(abi.encodePacked(result, "</script>"));
    }

    function variableScript(uint256 gameId, NFTDGameProject.DGameProject memory game) public view returns (string memory result) {
        result = '<script type="text/javascript" id="snippet-contract-code" name="VARIABLES">';
        result = string(abi.encodePacked(result, "const GAME_ID='", StringsUpgradeable.toString(gameId), "';"));
        result = string(abi.encodePacked(result, "const SALT_PASS='", StringsUtils.toHex(game._seed), "';"));
        result = string(abi.encodePacked(result, "const BFS_CONTRACT_ADDRESS='", StringsUpgradeable.toHexString(_bfs), "';"));
        result = string(abi.encodePacked(result, "const CHAIN_ID='", StringsUpgradeable.toString(getChainID()), "';"));
        result = string(abi.encodePacked(result, "const GAME_CONTRACT_ADDRESS='", StringsUpgradeable.toHexString(game._gameContract), "';"));
        result = string(abi.encodePacked(result, "const GAME_TOKEN_ERC20_ADDRESS='", StringsUpgradeable.toHexString(game._gameTokenERC20), "';"));
        result = string(abi.encodePacked(result, "const GAME_NFT_ERC721_ADDRESS='", StringsUpgradeable.toHexString(game._gameNFTERC721), "';"));
        result = string(abi.encodePacked(result, "const GAME_TOKEN_ERC1155_ADDRESS='", StringsUpgradeable.toHexString(game._gameNFTERC1155), "';"));
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
        (err, buff) = Inflate.puff(data, data.length * 5);
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

    function getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
