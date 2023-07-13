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
                loadDecompressLib(),
                libsScript(gameProjectDetail._scriptType), // load libs here
                variableScript(gameId, gameProjectDetail), // load vars
                '<style>', gameProjectDetail._styles, '</style>', // load css
                '</head><body>',
                scripts, // load main code of user
                "</body>",
                "</html>"
            ));
        result = scripts;
    }

    function loadDecompressLib() public view returns (string memory result) {
        result = "<script sandbox='allow-scripts' type='text/javascript' src='data:@file/javascript;base64,IWZ1bmN0aW9uKCl7InVzZSBzdHJpY3QiO3ZhciBlPXt9LHI9ZnVuY3Rpb24ocixuLHQsYSxpKXt2YXIgbz1uZXcgV29ya2VyKGVbbl18fChlW25dPVVSTC5jcmVhdGVPYmplY3RVUkwobmV3IEJsb2IoW3IrJzthZGRFdmVudExpc3RlbmVyKCJlcnJvciIsZnVuY3Rpb24oZSl7ZT1lLmVycm9yO3Bvc3RNZXNzYWdlKHskZSQ6W2UubWVzc2FnZSxlLmNvZGUsZS5zdGFja119KX0pJ10se3R5cGU6InRleHQvamF2YXNjcmlwdCJ9KSkpKTtyZXR1cm4gby5vbm1lc3NhZ2U9ZnVuY3Rpb24oZSl7dmFyIHI9ZS5kYXRhLG49ci4kZSQ7aWYobil7dmFyIHQ9RXJyb3IoblswXSk7dC5jb2RlPW5bMV0sdC5zdGFjaz1uWzJdLGkodCxudWxsKX1lbHNlIGkobnVsbCxyKX0sby5wb3N0TWVzc2FnZSh0LGEpLG99LG49VWludDhBcnJheSx0PVVpbnQxNkFycmF5LGE9VWludDMyQXJyYXksaT1uZXcgbihbMCwwLDAsMCwwLDAsMCwwLDEsMSwxLDEsMiwyLDIsMiwzLDMsMywzLDQsNCw0LDQsNSw1LDUsNSwwLDAsMCwwXSksbz1uZXcgbihbMCwwLDAsMCwxLDEsMiwyLDMsMyw0LDQsNSw1LDYsNiw3LDcsOCw4LDksOSwxMCwxMCwxMSwxMSwxMiwxMiwxMywxMywwLDBdKSxfPW5ldyBuKFsxNiwxNywxOCwwLDgsNyw5LDYsMTAsNSwxMSw0LDEyLDMsMTMsMiwxNCwxLDE1XSksZj1mdW5jdGlvbihlLHIpe2Zvcih2YXIgbj1uZXcgdCgzMSksaT0wO2k8MzE7KytpKW5baV09cis9MTw8ZVtpLTFdO2Zvcih2YXIgbz1uZXcgYShuWzMwXSksaT0xO2k8MzA7KytpKWZvcih2YXIgXz1uW2ldO188bltpKzFdOysrXylvW19dPV8tbltpXTw8NXxpO3JldHVybltuLG9dfSwkPWYoaSwyKSx1PSRbMF0sYz0kWzFdO3VbMjhdPTI1OCxjWzI1OF09Mjg7Zm9yKHZhciBsPWYobywwKSxzPWxbMF0sdj1uZXcgdCgzMjc2OCkscD0wO3A8MzI3Njg7KytwKXt2YXIgZD0oNDM2OTAmcCk+Pj4xfCgyMTg0NSZwKTw8MTtkPSg2MTY4MCYoZD0oNTI0MjgmZCk+Pj4yfCgxMzEwNyZkKTw8MikpPj4+NHwoMzg1NSZkKTw8NCx2W3BdPSgoNjUyODAmZCk+Pj44fCgyNTUmZCk8PDgpPj4+MX1mb3IodmFyIHc9ZnVuY3Rpb24oZSxyLG4pe2Zvcih2YXIgYSxpPWUubGVuZ3RoLG89MCxfPW5ldyB0KHIpO288aTsrK28pZVtvXSYmKytfW2Vbb10tMV07dmFyIGY9bmV3IHQocik7Zm9yKG89MDtvPHI7KytvKWZbb109ZltvLTFdK19bby0xXTw8MTtpZihuKXthPW5ldyB0KDE8PHIpO3ZhciAkPTE1LXI7Zm9yKG89MDtvPGk7KytvKWlmKGVbb10pZm9yKHZhciB1PW88PDR8ZVtvXSxjPXItZVtvXSxsPWZbZVtvXS0xXSsrPDxjLHM9bHwoMTw8YyktMTtsPD1zOysrbClhW3ZbbF0+Pj4kXT11fWVsc2UgZm9yKGE9bmV3IHQoaSksbz0wO288aTsrK28pZVtvXSYmKGFbb109dltmW2Vbb10tMV0rK10+Pj4xNS1lW29dKTtyZXR1cm4gYX0sZz1uZXcgbigyODgpLHA9MDtwPDE0NDsrK3ApZ1twXT04O2Zvcih2YXIgcD0xNDQ7cDwyNTY7KytwKWdbcF09OTtmb3IodmFyIHA9MjU2O3A8MjgwOysrcClnW3BdPTc7Zm9yKHZhciBwPTI4MDtwPDI4ODsrK3ApZ1twXT04O2Zvcih2YXIgaD1uZXcgbigzMikscD0wO3A8MzI7KytwKWhbcF09NTt2YXIgYj13KGcsOSwxKSx5PXcoaCw1LDEpLG09ZnVuY3Rpb24oZSl7Zm9yKHZhciByPWVbMF0sbj0xO248ZS5sZW5ndGg7KytuKWVbbl0+ciYmKHI9ZVtuXSk7cmV0dXJuIHJ9LE89ZnVuY3Rpb24oZSxyLG4pe3ZhciB0PXIvOHwwO3JldHVybihlW3RdfGVbdCsxXTw8OCk+Pig3JnIpJm59LGs9ZnVuY3Rpb24oZSxyKXt2YXIgbj1yLzh8MDtyZXR1cm4oZVtuXXxlW24rMV08PDh8ZVtuKzJdPDwxNik+Pig3JnIpfSxFPWZ1bmN0aW9uKGUpe3JldHVybihlKzcpLzh8MH0saj1mdW5jdGlvbihlLHIsaSl7KG51bGw9PXJ8fHI8MCkmJihyPTApLChudWxsPT1pfHxpPmUubGVuZ3RoKSYmKGk9ZS5sZW5ndGgpO3ZhciBvPW5ldygyPT1lLkJZVEVTX1BFUl9FTEVNRU5UP3Q6ND09ZS5CWVRFU19QRVJfRUxFTUVOVD9hOm4pKGktcik7cmV0dXJuIG8uc2V0KGUuc3ViYXJyYXkocixpKSksb30seD1bInVuZXhwZWN0ZWQgRU9GIiwiaW52YWxpZCBibG9jayB0eXBlIiwiaW52YWxpZCBsZW5ndGgvbGl0ZXJhbCIsImludmFsaWQgZGlzdGFuY2UiLCJzdHJlYW0gZmluaXNoZWQiLCJubyBzdHJlYW0gaGFuZGxlciIsLCJubyBjYWxsYmFjayIsImludmFsaWQgVVRGLTggZGF0YSIsImV4dHJhIGZpZWxkIHRvbyBsb25nIiwiZGF0ZSBub3QgaW4gcmFuZ2UgMTk4MC0yMDk5IiwiZmlsZW5hbWUgdG9vIGxvbmciLCJzdHJlYW0gZmluaXNoaW5nIiwiaW52YWxpZCB6aXAgZGF0YSJdLFM9ZnVuY3Rpb24oZSxyLG4pe3ZhciB0PUVycm9yKHJ8fHhbZV0pO2lmKHQuY29kZT1lLEVycm9yLmNhcHR1cmVTdGFja1RyYWNlJiZFcnJvci5jYXB0dXJlU3RhY2tUcmFjZSh0LFMpLCFuKXRocm93IHQ7cmV0dXJuIHR9LFI9ZnVuY3Rpb24oZSxyLHQpe3ZhciBhPWUubGVuZ3RoO2lmKCFhfHx0JiZ0LmYmJiF0LmwpcmV0dXJuIHJ8fG5ldyBuKDApO3ZhciBmPSFyfHx0LCQ9IXR8fHQuaTt0fHwodD17fSkscnx8KHI9bmV3IG4oMyphKSk7dmFyIGM9ZnVuY3Rpb24oZSl7dmFyIHQ9ci5sZW5ndGg7aWYoZT50KXt2YXIgYT1uZXcgbihNYXRoLm1heCgyKnQsZSkpO2Euc2V0KHIpLHI9YX19LGw9dC5mfHwwLHY9dC5wfHwwLHA9dC5ifHwwLGQ9dC5sLGc9dC5kLGg9dC5tLHg9dC5uLFI9OCphO2Rve2lmKCFkKXtsPU8oZSx2LDEpO3ZhciBUPU8oZSx2KzEsMyk7aWYodis9MyxUKXtpZigxPT1UKWQ9YixnPXksaD05LHg9NTtlbHNlIGlmKDI9PVQpe3ZhciB6PU8oZSx2LDMxKSsyNTcsTD1PKGUsdisxMCwxNSkrNCxVPXorTyhlLHYrNSwzMSkrMTt2Kz0xNDtmb3IodmFyIEI9bmV3IG4oVSksUD1uZXcgbigxOSksTT0wO008TDsrK00pUFtfW01dXT1PKGUsdiszKk0sNyk7dis9MypMO2Zvcih2YXIgQz1tKFApLEY9KDE8PEMpLTEsRD13KFAsQywxKSxNPTA7TTxVOyl7dmFyIE49RFtPKGUsdixGKV07dis9MTUmTjt2YXIgQT1OPj4+NDtpZihBPDE2KUJbTSsrXT1BO2Vsc2V7dmFyIEk9MCxZPTA7Zm9yKDE2PT1BPyhZPTMrTyhlLHYsMyksdis9MixJPUJbTS0xXSk6MTc9PUE/KFk9MytPKGUsdiw3KSx2Kz0zKToxOD09QSYmKFk9MTErTyhlLHYsMTI3KSx2Kz03KTtZLS07KUJbTSsrXT1JfX12YXIgcT1CLnN1YmFycmF5KDAseiksRz1CLnN1YmFycmF5KHopO2g9bShxKSx4PW0oRyksZD13KHEsaCwxKSxnPXcoRyx4LDEpfWVsc2UgUygxKX1lbHNle3ZhciBBPUUodikrNCxWPWVbQS00XXxlW0EtM108PDgsSD1BK1Y7aWYoSD5hKXskJiZTKDApO2JyZWFrfWYmJmMocCtWKSxyLnNldChlLnN1YmFycmF5KEEsSCkscCksdC5iPXArPVYsdC5wPXY9OCpILHQuZj1sO2NvbnRpbnVlfWlmKHY+Uil7JCYmUygwKTticmVha319ZiYmYyhwKzEzMTA3Mik7Zm9yKHZhciBKPSgxPDxoKS0xLEs9KDE8PHgpLTEsUT12OztRPXYpe3ZhciBJPWRbayhlLHYpJkpdLFc9ST4+PjQ7aWYoKHYrPTE1JkkpPlIpeyQmJlMoMCk7YnJlYWt9aWYoSXx8UygyKSxXPDI1NilyW3ArK109VztlbHNlIGlmKDI1Nj09Vyl7UT12LGQ9bnVsbDticmVha31lbHNle3ZhciBYPVctMjU0O2lmKFc+MjY0KXt2YXIgTT1XLTI1NyxaPWlbTV07WD1PKGUsdiwoMTw8WiktMSkrdVtNXSx2Kz1afXZhciBlZT1nW2soZSx2KSZLXSxlcj1lZT4+PjQ7ZWV8fFMoMyksdis9MTUmZWU7dmFyIEc9c1tlcl07aWYoZXI+Myl7dmFyIFo9b1tlcl07Rys9ayhlLHYpJigxPDxaKS0xLHYrPVp9aWYodj5SKXskJiZTKDApO2JyZWFrfWYmJmMocCsxMzEwNzIpO2Zvcih2YXIgZW49cCtYO3A8ZW47cCs9NClyW3BdPXJbcC1HXSxyW3ArMV09cltwKzEtR10scltwKzJdPXJbcCsyLUddLHJbcCszXT1yW3ArMy1HXTtwPWVufX10Lmw9ZCx0LnA9USx0LmI9cCx0LmY9bCxkJiYobD0xLHQubT1oLHQuZD1nLHQubj14KX13aGlsZSghbCk7cmV0dXJuIHA9PXIubGVuZ3RoP3I6aihyLDAscCl9LFQ9bmV3IG4oMCksej1mdW5jdGlvbihlLHIpe3ZhciBuPXt9O2Zvcih2YXIgdCBpbiBlKW5bdF09ZVt0XTtmb3IodmFyIHQgaW4gciluW3RdPXJbdF07cmV0dXJuIG59LEw9ZnVuY3Rpb24oZSxyLG4pe2Zvcih2YXIgdD1lKCksYT1lLnRvU3RyaW5nKCksaT1hLnNsaWNlKGEuaW5kZXhPZigiWyIpKzEsYS5sYXN0SW5kZXhPZigiXSIpKS5yZXBsYWNlKC9ccysvZywiIikuc3BsaXQoIiwiKSxvPTA7bzx0Lmxlbmd0aDsrK28pe3ZhciBfPXRbb10sZj1pW29dO2lmKCJmdW5jdGlvbiI9PXR5cGVvZiBfKXtyKz0iOyIrZisiPSI7dmFyICQ9Xy50b1N0cmluZygpO2lmKF8ucHJvdG90eXBlKXtpZigtMSE9JC5pbmRleE9mKCJbbmF0aXZlIGNvZGVdIikpe3ZhciB1PSQuaW5kZXhPZigiICIsOCkrMTtyKz0kLnNsaWNlKHUsJC5pbmRleE9mKCIoIix1KSl9ZWxzZSBmb3IodmFyIGMgaW4gcis9JCxfLnByb3RvdHlwZSlyKz0iOyIrZisiLnByb3RvdHlwZS4iK2MrIj0iK18ucHJvdG90eXBlW2NdLnRvU3RyaW5nKCl9ZWxzZSByKz0kfWVsc2UgbltmXT1ffXJldHVybltyLG5dfSxVPVtdLEI9ZnVuY3Rpb24oZSl7dmFyIHI9W107Zm9yKHZhciBuIGluIGUpZVtuXS5idWZmZXImJnIucHVzaCgoZVtuXT1uZXcgZVtuXS5jb25zdHJ1Y3RvcihlW25dKSkuYnVmZmVyKTtyZXR1cm4gcn0sUD1mdW5jdGlvbihlLG4sdCxhKXtpZighVVt0XSl7Zm9yKHZhciBpLG89IiIsXz17fSxmPWUubGVuZ3RoLTEsJD0wOyQ8ZjsrKyQpbz0oaT1MKGVbJF0sbyxfKSlbMF0sXz1pWzFdO1VbdF09TChlW2ZdLG8sXyl9dmFyIHU9eih7fSxVW3RdWzFdKTtyZXR1cm4gcihVW3RdWzBdKyI7b25tZXNzYWdlPWZ1bmN0aW9uKGUpe2Zvcih2YXIgayBpbiBlLmRhdGEpc2VsZltrXT1lLmRhdGFba107b25tZXNzYWdlPSIrbi50b1N0cmluZygpKyJ9Iix0LHUsQih1KSxhKX0sTT1mdW5jdGlvbigpe3JldHVybltuLHQsYSxpLG8sXyx1LHMsYix5LHYseCx3LG0sTyxrLEUsaixTLFIsWSxGLERdfSxDPWZ1bmN0aW9uKCl7cmV0dXJuW0EsSV19LEY9ZnVuY3Rpb24oZSl7cmV0dXJuIHBvc3RNZXNzYWdlKGUsW2UuYnVmZmVyXSl9LEQ9ZnVuY3Rpb24oZSl7cmV0dXJuIGUmJmUuc2l6ZSYmbmV3IG4oZS5zaXplKX0sTj1mdW5jdGlvbihlLHIsbix0LGEsaSl7dmFyIG89UChuLHQsYSxmdW5jdGlvbihlLHIpe28udGVybWluYXRlKCksaShlLHIpfSk7cmV0dXJuIG8ucG9zdE1lc3NhZ2UoW2Uscl0sci5jb25zdW1lP1tlLmJ1ZmZlcl06W10pLGZ1bmN0aW9uKCl7by50ZXJtaW5hdGUoKX19LEE9ZnVuY3Rpb24oZSl7KDMxIT1lWzBdfHwxMzkhPWVbMV18fDghPWVbMl0pJiZTKDYsImludmFsaWQgZ3ppcCBkYXRhIik7dmFyIHI9ZVszXSxuPTEwOzQmciYmKG4rPWVbMTBdfChlWzExXTw8OCkrMik7Zm9yKHZhciB0PShyPj4zJjEpKyhyPj40JjEpO3Q+MDt0LT0hZVtuKytdKTtyZXR1cm4gbisoMiZyKX0sST1mdW5jdGlvbihlKXt2YXIgcj1lLmxlbmd0aDtyZXR1cm4oZVtyLTRdfGVbci0zXTw8OHxlW3ItMl08PDE2fGVbci0xXTw8MjQpPj4+MH07ZnVuY3Rpb24gWShlLHIpe3JldHVybiBSKGUscil9ZnVuY3Rpb24gcShlLHIpe3JldHVybiBSKGUuc3ViYXJyYXkoQShlKSwtOCkscnx8bmV3IG4oSShlKSkpfXZhciBHPSJ1Ij50eXBlb2YgVGV4dERlY29kZXImJm5ldyBUZXh0RGVjb2RlcixWPTA7dHJ5e0cuZGVjb2RlKFQse3N0cmVhbTohMH0pLFY9MX1jYXRjaHt9d2luZG93Lmd1bnppcD1mdW5jdGlvbiBlKHIsbix0KXtyZXR1cm4gdHx8KHQ9bixuPXt9KSwiZnVuY3Rpb24iIT10eXBlb2YgdCYmUyg3KSxOKHIsbixbTSxDLGZ1bmN0aW9uKCl7cmV0dXJuW3FdfV0sZnVuY3Rpb24oZSl7cmV0dXJuIEYocShlLmRhdGFbMF0pKX0sMyx0KX19KCksZnVuY3Rpb24oKXsidXNlIHN0cmljdCI7bGV0IGU9YXN5bmMoZSxyPSExLG49InRleHQvamF2YXNjcmlwdCIpPT5uZXcgUHJvbWlzZSgodCxhKT0+e2xldCBpPWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoInNjcmlwdCIpO2kuc3JjPWUsaS5kZWZlcj1yLGkudHlwZT1uLGRvY3VtZW50LmhlYWQuYXBwZW5kQ2hpbGQoaSksaS5vbmxvYWQ9KCk9Pnt0KCEwKX0saS5vbmVycm9yPWU9PnthKGUpfSxpLm9uYWJvcnQ9ZT0+e2EoZSl9fSk7d2luZG93LmFkZER5bmFtaWNTY3JpcHQ9ZTtsZXQgcj1hc3luYyBlPT5uZXcgUHJvbWlzZShyPT57bGV0IG49ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgibGluayIpO24ucmVsPSJzdHlsZXNoZWV0IixuLmhyZWY9ZSxkb2N1bWVudC5oZWFkLmFwcGVuZENoaWxkKG4pLHIoITApfSk7ZnVuY3Rpb24gbihlLHIpe3I9cnx8IiI7bGV0IG49d2luZG93LmF0b2IoZSksdD1bXTtmb3IobGV0IGE9MCxpPW4ubGVuZ3RoO2E8aTthKz0xMDI0KXtsZXQgbz1uLnNsaWNlKGEsYSsxMDI0KSxfPUFycmF5KG8ubGVuZ3RoKTtmb3IobGV0IGY9MDtmPG8ubGVuZ3RoO2YrKylfW2ZdPW8uY2hhckNvZGVBdChmKTtsZXQgJD1uZXcgVWludDhBcnJheShfKTt0LnB1c2goJCl9cmV0dXJuIG5ldyBCbG9iKHQse3R5cGU6cn0pfXdpbmRvdy5hZGREeW5hbWljU3R5bGU9cix3aW5kb3cuYmFzZTY0VG9CbG9iPW4sd2luZG93LmRhdGFVUkl0b0Jsb2I9ZnVuY3Rpb24gZShyKXtsZXQgdD1yLnNwbGl0KCIsIilbMV0sYT1yLnNwbGl0KCIsIilbMF0uc3BsaXQoIjoiKVsxXS5zcGxpdCgiOyIpWzBdO3JldHVybiBuKHQsYSl9LHdpbmRvdy5ibG9iVG9CYXNlNjQ9ZnVuY3Rpb24gZShyKXtyZXR1cm4gbmV3IFByb21pc2UoZT0+e3ZhciBuPW5ldyBGaWxlUmVhZGVyO24ucmVhZEFzRGF0YVVSTChyKSxuLm9ubG9hZGVuZD1mdW5jdGlvbigpe2Uobi5yZXN1bHQpfX0pfSx3aW5kb3cucmFuZG9tTnVtYmVyPWZ1bmN0aW9uIGUocixuKXtyZXR1cm4gTWF0aC5yYW5kb20oKSoobi1yKStyfSx3aW5kb3cuaXNPYmplY3RFcXVhbHM9ZnVuY3Rpb24gZShyLG4pe2lmKHI9PT1uKXJldHVybiEwO2lmKCEociBpbnN0YW5jZW9mIE9iamVjdCl8fCEobiBpbnN0YW5jZW9mIE9iamVjdCl8fHIuY29uc3RydWN0b3IhPT1uLmNvbnN0cnVjdG9yKXJldHVybiExO2Zvcih2YXIgdCBpbiByKWlmKHIuaGFzT3duUHJvcGVydHkodCkmJighbi5oYXNPd25Qcm9wZXJ0eSh0KXx8clt0XSE9PW5bdF0mJigib2JqZWN0IiE9dHlwZW9mIHJbdF18fCFlKHJbdF0sblt0XSkpKSlyZXR1cm4hMTtmb3IodCBpbiBuKWlmKG4uaGFzT3duUHJvcGVydHkodCkmJiFyLmhhc093blByb3BlcnR5KHQpKXJldHVybiExO3JldHVybiEwfSx3aW5kb3cudXVpZHY0PWZ1bmN0aW9uIGUoKXtyZXR1cm4iMTAwMDAwMDAtMTAwMC00MDAwLTgwMDAtMTAwMDAwMDAwMDAwIi5yZXBsYWNlKC9bMDE4XS9nLGU9PihlXmNyeXB0by5nZXRSYW5kb21WYWx1ZXMobmV3IFVpbnQ4QXJyYXkoMSkpWzBdJjE1Pj5lLzQpLnRvU3RyaW5nKDE2KSl9O2xldCB0PShyLG4sdCk9PntsZXQgYT1uZXcgQmxvYihbcl0se3R5cGU6ImFwcGxpY2F0aW9uL2phdmFzY3JpcHQifSk7ZShVUkwuY3JlYXRlT2JqZWN0VVJMKGEpLG4sdCl9LGE9KGUscixuKT0+bmV3IFByb21pc2UoYT0+e2ZldGNoKFVSTC5jcmVhdGVPYmplY3RVUkwoZSkpLnRoZW4oZT0+ImFwcGxpY2F0aW9uL2phdmFzY3JpcHQiPT09ZS5oZWFkZXJzLmdldCgiQ29udGVudC1UeXBlIik/ZS50ZXh0KCkudGhlbihlPT57dChlLHIsbiksYSghMCl9KTplLmFycmF5QnVmZmVyKCkudGhlbihlPT57d2luZG93Lmd1bnppcChuZXcgVWludDhBcnJheShlKSwoZSxpKT0+e2xldCBvPW5ldyBUZXh0RGVjb2RlcigpLmRlY29kZShpKTt0KG8scixuKSxhKCEwKX0pfSkpfSk7d2luZG93LmdldEd6aXBGaWxlPWE7bGV0IGk9ZT0+bmV3IFByb21pc2Uocj0+e2ZldGNoKFVSTC5jcmVhdGVPYmplY3RVUkwoZSkpLnRoZW4oZT0+ZS5hcnJheUJ1ZmZlcigpLnRoZW4oZT0+e3dpbmRvdy5ndW56aXAobmV3IFVpbnQ4QXJyYXkoZSksKGUsbik9PntyKFVSTC5jcmVhdGVPYmplY3RVUkwobmV3IEJsb2IoW25ldyBVaW50OEFycmF5KG4sMCxuLmxlbmd0aCldKSkpfSl9KSl9KTt3aW5kb3cudW56aXBGaWxlPWl9KCk7'>";
        result = string(abi.encodePacked(result, "</script>"));
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

    function variableScript(uint256 gameId, NFTDGameProject.DGameProject memory game) public view returns (string memory result) {
        result = '<script type="text/javascript" id="snippet-contract-code">';
        result = string(abi.encodePacked(result, "const GAME_ID='", StringsUpgradeable.toString(gameId), "';"));
        result = string(abi.encodePacked(result, "const GAME_CONTRACT_ADDRESS='", StringsUpgradeable.toHexString(game._gameContract), "';"));
        result = string(abi.encodePacked(result, "const GAME_TOKEN_ERC20_ADDRESS='", StringsUpgradeable.toHexString(game._gameTokenERC20), "';"));
        result = string(abi.encodePacked(result, "const GAME_NFT_ERC721_ADDRESS='", StringsUpgradeable.toHexString(game._gameNFTERC721), "';"));
        result = string(abi.encodePacked(result, "const GAME_TOKEN_ERC1155_ADDRESS='", StringsUpgradeable.toHexString(game._gameNFTERC1155), "';"));
        result = string(abi.encodePacked(result, "const BFS_CONTRACT_ADDRESS='", StringsUpgradeable.toHexString(_bfs), "';"));
        result = string(abi.encodePacked(result, "const SALT_PASS='", StringsUtils.toHex(game._seed), "';"));
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
