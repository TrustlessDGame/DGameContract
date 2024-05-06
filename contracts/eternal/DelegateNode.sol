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
    event CreatePool(uint32 poolId);
    event Stake(address user, uint256 amount, uint32 poolId);
    event ActivePool(uint32 poolId);
    event DeactivePool(uint32 poolId);

    address public _admin;
    uint32 public _nextPoolId;
    uint256 public _defaultAmountToActive; // 8000 EAI
    mapping(uint32 => DelegateNodeStruct.PoolInfo) public _pools;
    uint32 public _defaultPoolFee; // 1000 => 10%


    function initialize(
        string memory name,
        string memory symbol,
        address admin
    )  initializer public {
        _admin = admin;
        _defaultAmountToActive = 8000 * 10**18;
        _defaultPoolFee = 1000;

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

//    function getPoolInfo(uint32 poolId) external view returns (DelegateNodeStruct.PoolInfo memory) {
//        return _pools[poolId];
//    }

    // ADMIN update amountToActive for a pool
    function adminUpdateAmountToActive(uint32 poolId, uint256 amount) external onlyAdmin {
        require(poolId > 0 && poolId <= _nextPoolId, Errors.INV_GAME_ID);
        require(amount > 0, Errors.INV_ADD);

        _pools[poolId].amountToActive = amount;
    }

    // Admin change fee percent for a pool
    function adminChangeFeePercent(uint32 poolId, uint32 feePercent) external onlyAdmin {
        require(poolId > 0 && poolId <= _nextPoolId, Errors.INV_GAME_ID);
        require(feePercent > 0, Errors.INV_ADD);

        _pools[poolId].feePercent = feePercent;
    }

    function adminCreatePool(uint32 amountPool) external onlyAdmin {
        // loop to PRE-CREATE pool
        for (uint32 i = 0; i < amountPool; i++) {
            _nextPoolId = _nextPoolId + 1;
            DelegateNodeStruct.PoolInfo storage pool = _pools[_nextPoolId];
            pool.status = DelegateNodeStruct.PoolStatus.INACTIVE;
            pool.id = _nextPoolId;
            pool.amountToActive = _defaultAmountToActive;
            pool.stakedAmount = 0;
            pool.feePercent = _defaultPoolFee;

            emit CreatePool(_nextPoolId);
        }
    }

    // stake function is payable, user dont input pool, contract will FIND FIRST pool INACTIVE to stake
    function stake(uint32 poolId, uint256 amount) external payable nonReentrant {
        require(amount > 0, Errors.INV_ADD);
        require(msg.value == amount, Errors.INV_ADD);
        require(poolId > 0, Errors.INV_ADD);

        // update pool info
        _pools[poolId].stakedAmount = _pools[poolId].stakedAmount + amount;
        _pools[poolId].stakedInfos.push(DelegateNodeStruct.StakedInfo({
            user: msg.sender,
            amount: amount,
            blockNumber: block.number
        }));

        if (_pools[poolId].stakedAmount >= _pools[poolId].amountToActive) {
            _pools[poolId].status = DelegateNodeStruct.PoolStatus.ACTIVE;

            // Emit for Backend enough $EAI to start a miner
            emit ActivePool(poolId); // BE listen, BE create wallet for miner, BE start miner manually
        }

        emit Stake(msg.sender, amount, poolId);
    }

    // withdraw $EAI, for admin only, $EAI is native token of chain
    function adminWithdraw(address to, uint256 amount) external onlyAdmin {
        require(to != Errors.ZERO_ADDR, Errors.INV_ADD);
        require(amount > 0, Errors.INV_ADD);

        payable(to).transfer(amount);
    }

    // withdraw $EAI by poolId, for admin only, $EAI is native token of chain
    function adminWithdrawByPoolId(uint32 poolId, address to, uint256 amount) external onlyAdmin {
        require(to != Errors.ZERO_ADDR, Errors.INV_ADD);
        require(amount > 0, Errors.INV_ADD);

        _pools[poolId].stakedAmount = _pools[poolId].stakedAmount - amount;
        payable(to).transfer(amount);
    }


}


