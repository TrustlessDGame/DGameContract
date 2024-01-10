pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../interfaces/IRunTogether.sol";
import "../libs/helpers/Errors.sol";
import "../libs/helpers/StringsUtils.sol";
import "../libs/structs/RunTogetherStruct.sol";


contract RunTogether is Initializable, ERC721PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, IRunTogether {
    address public _admin;
    address public _paramsAddress;
    uint256 public _currentGameId;
    mapping(address => bool) public _moderators;

    // event data
    mapping(uint256 => RunTogetherObjectStruct.RunTogetherEvent) private _events;

    // participant data
    mapping(uint256 => mapping(address => RunTogetherObjectStruct.RunTogetherParticipant)) private _participants;
    mapping(uint256 => mapping(string => mapping(address => bool))) private _groupParticipants;

    // sponsor data
    mapping(uint256 => mapping(address => uint256)) private _sponsorships;
    mapping(uint256 => mapping(address => mapping(address => uint256))) private _sponsors;

    function initialize(
        string memory name,
        string memory symbol,
        address admin,
        address paramsAddress
    ) initializer public {
        require(admin != Errors.ZERO_ADDR, Errors.INV_ADD);
        require(paramsAddress != Errors.ZERO_ADDR, Errors.INV_ADD);
        _paramsAddress = paramsAddress;
        _admin = admin;

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

    function setApproveModerator(address moderator, bool approval) external {
        require(msg.sender == _admin && moderator != Errors.ZERO_ADDR, Errors.ONLY_ADMIN_ALLOWED);
        _moderators[moderator] = approval;
    }

    function _paymentCreateEvent() internal {
        if (msg.sender != _admin) {
            require(msg.value >= 10000);
            (bool success,) = address(this).call{value: msg.value}("");
            require(success);
        }
    }

    function createEvent(RunTogetherObjectStruct.RunTogetherEvent memory eventData) external payable nonReentrant returns (uint256) {
        // verify
        require(msg.sender == _admin || _moderators[msg.sender]);
        require(eventData._creatorAddr != Errors.ZERO_ADDR, Errors.INV_ADD);
        require(bytes(eventData._name).length > 3 && bytes(eventData._creator).length > 3 && bytes(eventData._image).length > 0, Errors.MISSING_NAME);

        _currentGameId++;
        _paymentCreateEvent();
        _events[_currentGameId] = eventData;
        _safeMint(eventData._creatorAddr, _currentGameId);

        return _currentGameId;
    }

    function join(uint256 eventId, address participantAddr, RunTogetherObjectStruct.RunTogetherParticipant memory data) external payable nonReentrant {
        require(_exists(eventId), Errors.INV_GAME_ID);
        require(_moderators[msg.sender], Errors.ONLY_MODERATOR);
        require(StringsUtils.compareStringWithEmpty(_participants[eventId][participantAddr]._twitterId));
        require(_groupParticipants[eventId][data._groupId][participantAddr] == false);

        _participants[eventId][participantAddr] = data;
        _groupParticipants[eventId][data._groupId][participantAddr] = true;
    }

    function setParticipantData(uint256 eventId, address participantAddr, string memory data) external nonReentrant {
        require(_exists(eventId), Errors.INV_GAME_ID);
        require(_groupParticipants[eventId][_participants[eventId][participantAddr]._groupId][participantAddr]);
        require(!StringsUtils.compareStringWithEmpty(_participants[eventId][participantAddr]._twitterId));
        require(_moderators[msg.sender], Errors.ONLY_MODERATOR);

        _participants[eventId][participantAddr]._data = data;
    }

    function eventDetail(uint256 eventId) external view returns (RunTogetherObjectStruct.RunTogetherEvent memory eventData) {
        require(_exists(eventId), Errors.INV_GAME_ID);
        eventData = _events[eventId];
    }

    function getParticipantData(uint256 eventId, address participantAddr) external view returns (RunTogetherObjectStruct.RunTogetherParticipant memory data) {
        require(_exists(eventId), Errors.INV_GAME_ID);
        data = _participants[eventId][participantAddr];
    }

    function updateEventDescription(uint256 eventId, string memory desc) external {
        require(msg.sender == _admin || msg.sender == _events[eventId]._creatorAddr, Errors.ONLY_ADMIN_ALLOWED);
        require(_exists(eventId), Errors.INV_GAME_ID);
        _events[eventId]._desc = desc;
    }

    function updateEventImage(uint256 eventId, string memory image) external {
        require(msg.sender == _admin || msg.sender == _events[eventId]._creatorAddr, Errors.ONLY_ADMIN_ALLOWED);
        require(_exists(eventId), Errors.INV_GAME_ID);
        _events[eventId]._image = image;
    }

    function receiveTokens(uint256 eventId, address tokenAddress, uint256 amount) external {
        // Ensure that the sender has approved the contract to transfer tokens
        require(IERC20Upgradeable(tokenAddress).transferFrom(msg.sender, address(this), amount), Errors.TRANSFER_FAIL);

        _sponsorships[eventId][tokenAddress] = amount;
        _sponsors[eventId][msg.sender][tokenAddress] += amount;

        // Emit an event to log the token transfer
        emit TokensReceived(msg.sender, eventId, tokenAddress, amount);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        require(1 == 0);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        require(1 == 0);
    }
}
