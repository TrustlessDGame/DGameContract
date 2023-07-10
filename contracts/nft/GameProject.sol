pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "../libs/operator-filter-registry/upgradeable/DefaultOperatorFiltererUpgradeable.sol";

import "../interfaces/IGameProject.sol";

import "../libs/structs/NFTGame.sol";
import "../libs/helpers/Errors.sol";

contract GameProject is Initializable, ERC721PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, IERC2981Upgradeable, IGameProject, DefaultOperatorFiltererUpgradeable {
    // super admin
    address public _admin;
    // parameter control address
    address public _paramsAddress;
    // game data
    address public _gameDataContextAddr;
    // _currentGameId is tokenID of game nft
    uint256 private _currentGameId;

    mapping(uint256 => NFTGame.Game) _games;

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
        _gameDataContextAddr = projectDataContextAddr;

        __ERC721_init(name, symbol);
        __ReentrancyGuard_init();
        __ERC721Pausable_init();
        __DefaultOperatorFilterer_init();
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

    function mint(
        NFTGame.Game memory game
    ) external payable nonReentrant returns (uint256) {
        // verify
        require(bytes(game._name).length > 3 && bytes(game._creator).length > 3 && bytes(project._image).length > 0, Errors.MISSING_NAME);

        return _currentGameId;
    }

    function tokenURI(uint256 gameId) override public view returns (string memory result) {
        require(_exists(gameId), Errors.INV_TOKEN);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        // NOT allow transfer
    }

    function burn(uint256 tokenId) public override {
        // NOT allow burn
    }
}
