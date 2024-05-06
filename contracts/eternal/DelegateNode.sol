pragma solidity ^0.8.0;

// DelegateNode contract is similar to staking contract, allow users stake $EAI, if enough $EAI staked, backend will manually start a miner
// Miner run something outside login and earn reward, then reward will be split to users
// mean a user dont have enough $EAI to run a miner, they stake with other people to run a miner
// Contract is upgradeable and keep track about stake info (address, amount, block_time, etc)
// Will create pool to receive $EAI stake from user
// We have some pools (similar to ERC-721), each pools have different state: id, status, staked amount

import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import "../libs/helpers/Errors.sol";
import "../libs/helpers/StringsUtils.sol";
import "../libs/structs/DelegateNode.sol";

contract DelegateNode is Initializable, ERC721PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using AddressUpgradeable for address;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // event
    event Stake(address user, uint256 amount, uint32 poolId);

    address public _admin;
    uint32 public _nextPoolId;
    uint256 public _defaultAmountToActive; // 8000 EAI
    mapping(uint32 => DelegateNodeStruct.PoolInfo) public _pools;

    function initialize(
        string memory name,
        string memory symbol,
        address admin
    )  initializer public {
        _admin = admin;
        _defaultAmountToActive = 8000 * 10**18;

        __ERC721_init("DelegateNode", "DN");
        __ReentrancyGuard_init();
        __ERC721Pausable_init();
        __Ownable_init();
    }

    // modifier admin only
    modifier onlyAdmin() {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _;
    }

    function changeAdmin(address newAdm) external {
        require(msg.sender == _admin && newAdm != Errors.ZERO_ADDR, Errors.ONLY_ADMIN_ALLOWED);

        // change admin
        if (_admin != newAdm) {
            address _previousAdmin = _admin;
            _admin = newAdm;
        }
    }

    function getPoolInfo(uint32 poolId) external view returns (DelegateNodeStruct.PoolInfo memory) {
        return _pools[poolId];
    }

    // ADMIN update amountToActive for a pool
    function adminUpdateAmountToActive(uint32 poolId, uint256 amount) external onlyAdmin {
        require(poolId > 0 && poolId <= _nextPoolId, Errors.INV_GAME_ID);
        require(amount > 0, Errors.INV_ADD);

        _pools[poolId].amountToActive = amount;
    }

    function adminCreatePool(uint32 amountPool) external onlyAdmin {
        // loop to PRE-CREATE pool
        for (uint32 i = 0; i < amountPool; i++) {
            _nextPoolId = _nextPoolId + 1;
            _pools[_nextPoolId] = DelegateNodeStruct.PoolInfo({
                status: DelegateNodeStruct.PoolStatus.INACTIVE, // only convert to ACTIVE when enough $EAI staked
                id: _nextPoolId,
                amountToActive: _defaultAmountToActive,
                stakedAmount: 0,
                stakedInfos: new DelegateNodeStruct.StakedInfo[](0)
            });
        }
    }

    function findFirstInactivePool() internal view returns (uint32) {
        for (uint32 i = 1; i <= _nextPoolId; i++) {
            if (_pools[i].status == DelegateNodeStruct.PoolStatus.INACTIVE) {
                return i;
            }
        }

        return 0;
    }

    // stake function is payable, user dont input pool, contract will FIND FIRST pool INACTIVE to stake
    function stake(uint256 amount) external payable nonReentrant {
        require(amount > 0, Errors.INV_ADD);
        require(msg.value == amount, Errors.INV_ADD);

        // find first inactive pool
        uint32 poolId = findFirstInactivePool();
        require(poolId > 0, Errors.INV_ADD);

        // update pool info
        _pools[poolId].stakedAmount = _pools[poolId].stakedAmount + amount;
        _pools[poolId].stakedInfos.push(DelegateNodeStruct.StakedInfo({
            user: msg.sender,
            amount: amount,
            blockTime: block.timestamp
        }));

        _pools[poolId].stakedAmounts[msg.sender] = _pools[poolId].stakedAmounts[msg.sender] + amount;

        emit Stake(msg.sender, amount, poolId);
    }
}


