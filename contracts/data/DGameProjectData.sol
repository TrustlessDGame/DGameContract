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
        string memory html = this.tokenHTML(gameId);
        if (bytes(html).length > 0) {
            html = string(abi.encodePacked('data:text/html;base64,', Base64.encode(abi.encodePacked(html))));
        }
        string memory animationURI = string(abi.encodePacked(', "animation_url":"', html, '"'));

        ctx._name = string(abi.encodePacked(d._name, " #", StringsUpgradeable.toString(gameId)));
        ctx._desc = d._desc;
        string memory inflate;
        Inflate.ErrorCode err;
        (inflate, err) = inflateString(ctx._desc);
        if (err == Inflate.ErrorCode.ERR_NONE) {
            ctx._desc = inflate;
        }
        ctx._image = d._image;
        ctx._animationURI = animationURI;
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
                ctx._animationURI,
                '}'
            )
        );
    }

    function tokenHTML(uint256 gameId) external view returns (string memory result) {
        IDGameProject gamesProjectContract = IDGameProject(_gamesProjectAddr);
        NFTDGameProject.DGameProject memory gameProjectDetail = gamesProjectContract.gameDetail(gameId);
        if (gameProjectDetail._scripts.length == 0) {
            result = "";
        } else if (gameProjectDetail._scripts.length == 1) {
            // for old format which used simple template file
            string memory scripts = "";
            string memory inflate;
            Inflate.ErrorCode err;
            if (bytes(gameProjectDetail._scripts[0]).length > 0) {
                (inflate, err) = this.inflateString(gameProjectDetail._scripts[0]);
                if (err != Inflate.ErrorCode.ERR_NONE) {
                    scripts = string(abi.encodePacked(scripts, gameProjectDetail._scripts[0]));
                } else {
                    scripts = string(abi.encodePacked(scripts, inflate));
                }
            }
            result = scripts;
        } else {
            // for new format which used advance template file for supporting fully on-chain javascript libs
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
                    "<html>",
                    "<head><meta charset='UTF-8'>",
                    libsScript(gameProjectDetail._scriptType), // load libs here
                    '<style>', gameProjectDetail._styles, '</style>', // load css
                    '</head><body>',
                    scripts, // load main code of user
                    "</body>",
                    "</html>"
                ));
            result = scripts;
        }
    }

    function loadLibFileContent(string memory fileName) internal view returns (string memory script) {
        script = "";
        IBFS bfs = IBFS(_bfs);
        // count file
        address scriptProvider = IParameterControl(_paramAddr).getAddress("SCRIPT_PROVIDER");
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
        result = string(abi.encodePacked(result, loadLibFileContent(fileName)));
        result = string(abi.encodePacked(result, "</script>"));
    }

    function libsScript(string[] memory libs) private view returns (string memory scriptLibs) {
        scriptLibs = "";
        for (uint256 i = 0; i < libs.length; i++) {
            string memory lib = libScript(libs[i]);
            scriptLibs = string(abi.encodePacked(scriptLibs, lib));
        }
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
