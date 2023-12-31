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

    function gameHTML(uint256 gameId) external view returns (string memory) {
        NFTDGameProject.DGameProject memory gameProjectDetail = IDGameProject(_gamesProjectAddr).gameDetail(gameId);
        string memory scripts = string(abi.encodePacked(
                "<html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'/>",
                loadDecompressLibAndABIJsonInterfaceBasic(), // load decompress lib and load abi json interface: erc-20, erc-1155, erc-721, bfs
                libsScript(gameProjectDetail._scriptType), // load libs here
                variableScript(gameId, gameProjectDetail) // load vars
            ));
        return scripts;
    }

    function gameAssetsHtml(uint256 gameId) external view returns (string memory) {
        NFTDGameProject.DGameProject memory gameProjectDetail = IDGameProject(_gamesProjectAddr).gameDetail(gameId);
        string memory scripts = string(abi.encodePacked(
                loadContractInteractionBasic(), // wallet, bfs call asset, ...
                assetsScript(gameId, gameProjectDetail), // load assets
                loadInternalStyle() // load internal style css
            ));
        return scripts;
    }

    function gameStyleHtml(uint256 gameId) external view returns (string memory) {
        NFTDGameProject.DGameProject memory gameProjectDetail = IDGameProject(_gamesProjectAddr).gameDetail(gameId);
        string memory scripts = string(abi.encodePacked(loadStyles(gameProjectDetail._styles), '</head>' // load css
            ));
        return scripts;
    }

    function gameScriptsHtml(uint256 gameId) external view returns (string memory) {
        NFTDGameProject.DGameProject memory gameProjectDetail = IDGameProject(_gamesProjectAddr).gameDetail(gameId);
        string memory scripts = "<body>";
        for (uint256 i = 0; i < gameProjectDetail._scripts.length; i++) {
            scripts = string(abi.encodePacked(scripts, '<script name="dev">getGzipFile(dataURItoBlob("', gameProjectDetail._scripts[i], '"));</script>'));
        }
        scripts = string(abi.encodePacked(scripts, loadPreloadScript()));
        return scripts;
    }

    function gameHTMLFooter() external view returns (string memory) {
        return "</body></html>";
    }

    function loadInternalStyle() internal view returns (string memory result) {
        result = string(abi.encodePacked(
                '<link rel="stylesheet" name="INTERNAL_STYLE" type="text/css" href="data:text/css;base64,',
                IParameterControl(_paramAddr).get(DGameProjectDataConfigs.INTERNAL_STYLE),
                '"/>'));
    }

    function loadStyles(string memory style) internal view returns (string memory result) {
        result = string(abi.encodePacked('<link rel="stylesheet" name="DEV_STYLE" type="text/css" href="', style, '"/>'));
    }

    function loadPreloadScript() internal view returns (string memory result) {
        // run preload script
        result = string(abi.encodePacked(
                "<script sandbox='allow-scripts' type='text/javascript' name='PRELOAD_SCRIPT' src='data:@file/javascript;base64,",
                IParameterControl(_paramAddr).get(DGameProjectDataConfigs.PRELOAD_SCRIPT),
                "'></script>")
        );
    }

    function loadDecompressLibAndABIJsonInterfaceBasic() internal view returns (string memory result) {
        result = string(abi.encodePacked("<script sandbox='allow-scripts' type='text/javascript' name='DECOMPRESS_LIB' src='data:@file/javascript;base64,",
            IParameterControl(_paramAddr).get(DGameProjectDataConfigs.DECOMPRESS_LIB), "'></script><script sandbox='allow-scripts' type='text/javascript' name='ABI_JSON_BASIC' src='data:@file/javascript;base64,",
            IParameterControl(_paramAddr).get(DGameProjectDataConfigs.ABI_JSON_BASIC), "'></script>"));
    }

    function loadContractInteractionBasic() internal view returns (string memory result) {
        string memory etherjs = loadLibFileContent("ethersumdjs@5.7.2.js.gz");
        string memory cryptojs = loadLibFileContent("cryptojsmin@4.1.1.js.gz");
        result = string(abi.encodePacked("<script sandbox='allow-scripts' type='text/javascript' name='CONTRACT_INTERACTION_BASIC'>(async () => {await getGzipFile(dataURItoBlob('",
            etherjs,
            "'));await getGzipFile(dataURItoBlob('",
            cryptojs,
            "'));await getGzipFile(dataURItoBlob('",
            IParameterControl(_paramAddr).get(DGameProjectDataConfigs.CONTRACT_INTERACTION_BASIC),
            "'))})();</script>"));
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

    function compare(string memory str1, string memory str2) internal pure returns (bool) {
        if (bytes(str1).length != bytes(str2).length) {
            return false;
        }
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

    function libsScript(string[] memory libs) private view returns (string memory result) {
        result = '<script type="text/javascript">let LIB_ASSETS={';
        for (uint256 i = 0; i < libs.length; i++) {
            if (!compare("ethersumdjs@5.7.2.js.gz", libs[i]) && !compare("cryptojsmin@4.1.1.js.gz", libs[i])) {
                result = string(abi.encodePacked(result, "'", libs[i], "':'bfs://",
                    StringsUpgradeable.toString(getChainID()), "/",
                    StringsUpgradeable.toHexString(_bfs), "/",
                    StringsUpgradeable.toHexString(IParameterControl(_paramAddr).getAddress(DGameProjectDataConfigs.SCRIPT_PROVIDER)), "/",
                    libs[i], "',"));
            }
        }
        result = string(abi.encodePacked(result, "};</script>"));
    }

    function assetsScript(uint256 gameId, NFTDGameProject.DGameProject memory game) public view returns (string memory result) {
        result = '<script type="text/javascript">let GAME_ASSETS={';
        for (uint256 i = 0; i < game._bfsAssetsKey.length; i++) {
            result = string(abi.encodePacked(result, "'", game._bfsAssetsKey[i], "':'", game._bfsAssetsValue[i], "',"));
        }
        result = string(abi.encodePacked(result, "};</script>"));
    }

    function variableScript(uint256 gameId, NFTDGameProject.DGameProject memory game) internal view returns (string memory result) {
        result = string(abi.encodePacked("<script type='text/javascript' name='VARIABLES'>const GAME_ID='", StringsUpgradeable.toString(gameId),
            "';const SALT_PASS='", StringsUtils.toHex(game._seed),
            "';const CHAIN_ID='", StringsUpgradeable.toString(getChainID()),
            "';const RPC='", IParameterControl(_paramAddr).get(DGameProjectDataConfigs.RPC_LINK),
            "';const RPC_EXPLORER='", IParameterControl(_paramAddr).get(DGameProjectDataConfigs.RPC_EXPLORER_LINK),
            "';const NETWORK_NAME='", IParameterControl(_paramAddr).get(DGameProjectDataConfigs.NETWORK_NAME),
            "';const CURRENCY_SYMBOL='", IParameterControl(_paramAddr).get(DGameProjectDataConfigs.CURRENCY_SYMBOL),
            "';const PLAY_MODE=", StringsUpgradeable.toString(game._gameMode)
            ));

        result = string(abi.encodePacked(result,
            ";const PLAY_MODE_API='", IParameterControl(_paramAddr).get(DGameProjectDataConfigs.PLAY_MODE_API),
            "';const GAME_CONTRACT_ADDRESS='", StringsUpgradeable.toHexString(game._gameContract),
            "';const GAME_TOKEN_ERC20_ADDRESS='", StringsUpgradeable.toHexString(game._gameTokenERC20),
            "';const GAME_NFT_ERC721_ADDRESS='", StringsUpgradeable.toHexString(game._gameNFTERC721),
            "';const GAME_TOKEN_ERC1155_ADDRESS='", StringsUpgradeable.toHexString(game._gameNFTERC1155),
            "';</script>"));
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
