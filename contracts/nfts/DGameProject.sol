pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "../interfaces/IDGameProject.sol";
import "../libs/helpers/Errors.sol";
import "../libs/structs/NFTDGameProject.sol";

import "../libs/configs/DGameProjectConfigs.sol";

import "../interfaces/IDGameProjectData.sol";
import "../interfaces/IParameterControl.sol";

contract DGameProject is Initializable, ERC721PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, IDGameProject {
    // super admin
    address public _admin;
    // parameter control address
    address public _paramsAddress;
    // game data
    address public _gameDataContextAddr;
    // _currentGameId is tokenID of game nft
    uint256 private _currentGameId;

    mapping(uint256 => NFTDGameProject.DGameProject) _games;

    function initialize(
        string memory name,
        string memory symbol,
        address admin,
        address paramsAddress,
        address gameDataContextAddr
    ) initializer public {
        require(admin != Errors.ZERO_ADDR, Errors.INV_ADD);
        require(paramsAddress != Errors.ZERO_ADDR, Errors.INV_ADD);
        _paramsAddress = paramsAddress;
        _admin = admin;
        _gameDataContextAddr = gameDataContextAddr;

        __ERC721_init(name, symbol);
        __ReentrancyGuard_init();
        __ERC721Pausable_init();
        __Ownable_init();
    }

    function changeAdmin(address newAdm) external {
        require(msg.sender == _admin && newAdm != Errors.ZERO_ADDR, Errors.ONLY_ADMIN_ALLOWED);

        // change admin
        if (_admin != newAdm) {
            address _previousAdmin = _admin;
            _admin = newAdm;
        }
    }

    function changeParamAddr(address newAddr) external {
        require(msg.sender == _admin && newAddr != Errors.ZERO_ADDR, Errors.ONLY_ADMIN_ALLOWED);

        // change
        if (_paramsAddress != newAddr) {
            _paramsAddress = newAddr;
        }
    }

    function changeDataContextAddr(address newAddr) external {
        require(msg.sender == _admin && newAddr != Errors.ZERO_ADDR, Errors.ONLY_ADMIN_ALLOWED);

        // change
        if (_gameDataContextAddr != newAddr) {
            _gameDataContextAddr = newAddr;
        }
    }

    function _paymentMintGameProject() internal {
        if (msg.sender != _admin) {
            IParameterControl _p = IParameterControl(_paramsAddress);
            // at least require value 1ETH
            uint256 operationFee = _p.getUInt256(DGameProjectConfigs.CREATE_GAME_PROJECT_FEE);
            if (operationFee > 0) {
                address operationFeeToken = _p.getAddress(DGameProjectConfigs.CREATE_GAME_FEE_TOKEN);
                address operatorTreasureAddress = address(this);
                address operatorTreasureConfig = _p.getAddress(DGameProjectConfigs.OPERATOR_TREASURE_ADDR);
                if (operatorTreasureConfig != Errors.ZERO_ADDR) {
                    operatorTreasureAddress = operatorTreasureConfig;
                }
                if (!(operationFeeToken == Errors.ZERO_ADDR)) {
                    IERC20Upgradeable tokenERC20 = IERC20Upgradeable(operationFeeToken);
                    // transfer erc-20 token to this contract
                    require(tokenERC20.transferFrom(
                            msg.sender,
                            operatorTreasureAddress,
                            operationFee
                        ));
                } else {
                    require(msg.value >= operationFee);
                    (bool success,) = operatorTreasureAddress.call{value : msg.value}("");
                    require(success);
                }
            }
        }
    }

    function mint(
        NFTDGameProject.DGameProject memory game
    ) external payable nonReentrant returns (uint256) {
        // verify
        require(game._creatorAddr != Errors.ZERO_ADDR, Errors.INV_ADD);
        require(bytes(game._name).length > 3 && bytes(game._creator).length > 3 && bytes(game._image).length > 0, Errors.MISSING_NAME);
        require(game._gameContract != Errors.ZERO_ADDR, Errors.INV_ADD_GAME_CONTRACT);

        _currentGameId++;
        _paymentMintGameProject();
        _games[_currentGameId] = game;
        _safeMint(game._creatorAddr, _currentGameId);

        return _currentGameId;
    }

    function updateGameProjectScriptType(
        uint256 gameId,
        string memory scriptType,
        uint256 i
    )
    external
    {
        require(msg.sender == _admin || msg.sender == _games[gameId]._creatorAddr, Errors.ONLY_ADMIN_ALLOWED);
        require(_exists(gameId), Errors.INV_GAME_ID);
        _games[gameId]._scriptType[i] = scriptType;
    }

    /* @UpdateProject
    */
    function addGameProjectScript(uint256 gameId, string memory _script)
    external
    {
        require(msg.sender == _admin || msg.sender == _games[gameId]._creatorAddr, Errors.ONLY_ADMIN_ALLOWED);
        require(_exists(gameId), Errors.INV_GAME_ID);
        _games[gameId]._scripts.push(_script);
    }

    function updateGameProjectScript(uint256 gameId, uint256 scriptIndex, string memory script)
    external
    {
        require(msg.sender == _admin || msg.sender == _games[gameId]._creatorAddr, Errors.ONLY_ADMIN_ALLOWED);
        require(_exists(gameId), Errors.INV_GAME_ID);
        _games[gameId]._scripts[scriptIndex] = script;
    }

    function deleteGameProjectScript(uint256 gameId, uint256 scriptIndex)
    external
    {
        require(msg.sender == _admin || msg.sender == _games[gameId]._creatorAddr, Errors.ONLY_ADMIN_ALLOWED);
        require(_exists(gameId), Errors.INV_GAME_ID);
        delete _games[gameId]._scripts[scriptIndex];
    }

    function updateGameProjectName(uint256 gameId, string memory projectName)
    external {
        require(msg.sender == _admin || msg.sender == _games[gameId]._creatorAddr, Errors.ONLY_ADMIN_ALLOWED);
        require(_exists(gameId), Errors.INV_GAME_ID);
        _games[gameId]._name = projectName;
    }

    function updateGameCreatorName(uint256 gameId, string memory creatorName)
    external {
        require(msg.sender == _admin || msg.sender == _games[gameId]._creatorAddr, Errors.ONLY_ADMIN_ALLOWED);
        require(_exists(gameId), Errors.INV_GAME_ID);
        _games[gameId]._creator = creatorName;
    }

    function gameDetail(uint256 gameId) external view returns (NFTDGameProject.DGameProject memory game) {
        require(_exists(gameId), Errors.INV_GAME_ID);
        game = _games[gameId];
    }

    function tokenURI(uint256 gameId) override public view returns (string memory result) {
        require(_exists(gameId), Errors.INV_GAME_ID);
        result = IDGameProjectData(_gameDataContextAddr).gameURI(gameId);
    }

    function ethersjsLibScript(uint256 chunkIndex) public view returns (bytes memory data, int256 nextChunkIndex) {
        (data, nextChunkIndex) = IDGameProjectData(_gameDataContextAddr).ethersjsLibScript("", chunkIndex);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        require(1 == 0);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        require(1 == 0);
    }
}