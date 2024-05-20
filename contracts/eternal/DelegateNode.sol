pragma solidity ^0.8.0;

// DelegateNode contract is similar to staking contract, allow users stake $EAI, if enough $EAI staked, backend will manually start a miner
// Miner run something outside login and earn reward, then reward will be split to users
// mean a user dont have enough $EAI to run a miner, they stake with other people to run a miner
// Contract is upgradeable and keep track about stake info (address, amount, block_time, etc)
// Will create pool to receive $EAI stake from user
// We have some pools (similar to ERC-721), each pools have different state: id, status, staked amount

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import "../libs/helpers/Errors.sol";
import "../libs/structs/DelegateNode.sol";

contract DelegateNode is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using AddressUpgradeable for address;

    // event
    event CreatePool(DelegateNodeStruct.PoolInfo poolInfo);
    event Stake(address user, uint256 amount, DelegateNodeStruct.PoolInfo poolInfo);
    event ActivePool(DelegateNodeStruct.PoolInfo poolInfo);
    event DeActivePool(DelegateNodeStruct.PoolInfo poolInfo);
    event UnStake(address user, uint256 amount, uint32 poolId, uint256 claimedBlock);
    event ClaimUnStake(address user, uint256 amount, uint32 poolId, uint256 claimedBlock);
    event ReStakeUnStakedPool(address user, uint256 unStakedAmount, uint32 oldPoolId, uint32 newPoolId);
    event AdminWithdraw(address to, uint256 amount, DelegateNodeStruct.PoolInfo poolInfo);

    address public _admin;
    address public _poolAdmin;
    uint32 public _nextPoolId;
    uint256 public _defaultAmountToActive; // 8000 EAI
    mapping(uint32 => DelegateNodeStruct.PoolInfo) public _pools;
    uint32 public _defaultPoolFee; // 1000 => 10% (0.1)
    uint256 public _defaultWaitBlock; // (21 +7 )day * 24 hour * 60 min * 30 block (block time  = 2s)
    address public _moderator;
    mapping(uint32 => mapping(address => DelegateNodeStruct.UserPooInfo)) public _userPoolInfo;

    error FailedTransfer();

    function initialize(
        address admin,
        address poolAdmin,
        address moderator
    ) initializer public {
        _nextPoolId = 1;
        _admin = admin;
        _poolAdmin = poolAdmin;
        _moderator = moderator;
        _defaultAmountToActive = 100 * 10 ** 18;
        _defaultPoolFee = 1000;
        _defaultWaitBlock = 1;
        __ReentrancyGuard_init();
        __Ownable_init();
    }

    // modifier admin only
    modifier onlyAdmin() {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _;
    }

    modifier onlyPoolAdmin() {
        require(msg.sender == _poolAdmin, Errors.ONLY_ADMIN_ALLOWED);
        _;
    }

    modifier onlyAdminOrModerator() {
        require(msg.sender == _admin || msg.sender == _moderator, Errors.ONLY_ADMIN_ALLOWED);
        _;
    }

    function changeAdmin(address newAdm) external onlyAdmin {
        require(newAdm != Errors.ZERO_ADDR, Errors.ONLY_ADMIN_ALLOWED);
        _admin = newAdm;
    }

    function changeModerator(address newModerator) external onlyAdmin {
        require(newModerator != Errors.ZERO_ADDR, Errors.ONLY_ADMIN_ALLOWED);
        _moderator = newModerator;
    }

    function adminUpdateAmountToActive(uint32 poolId, uint256 amount) external onlyAdminOrModerator {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_GAME_ID);
        require(amount > 0, Errors.INV_ADD);

        _pools[poolId].amountToActive = amount;
    }

    function adminSetName(uint32 poolId, string memory name) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_GAME_ID);

        _pools[poolId].name = name;
    }

    function adminSetImage(uint32 poolId, string memory image) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_GAME_ID);

        _pools[poolId].image = image;
    }

    function adminChangeFeePercent(uint32 poolId, uint32 feePercent) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_GAME_ID);
        require(feePercent > 0, Errors.INV_ADD);

        _pools[poolId].feePercent = feePercent;
    }

    function adminCreatePool(uint32 amountPool) external onlyAdminOrModerator {
        // loop to PRE-CREATE pool; amountPool is number of pool want to pre-create
        for (uint32 i = 0; i < amountPool; i++) {
            DelegateNodeStruct.PoolInfo storage pool = _pools[_nextPoolId];
            pool.status = DelegateNodeStruct.PoolStatus.INACTIVE;
            pool.id = _nextPoolId;
            pool.amountToActive = _defaultAmountToActive;
            pool.stakedAmount = 0;
            pool.feePercent = _defaultPoolFee;

            _nextPoolId = _nextPoolId + 1;
            emit CreatePool(_pools[pool.id]);
        }
    }

    function internalUpdatePoolInfo(uint32 poolId, uint256 amount) private {
        // update pool info
        _pools[poolId].stakedAmount = _pools[poolId].stakedAmount + amount;
        _pools[poolId].stakedInfos.push(DelegateNodeStruct.StakedInfo({
            user: msg.sender,
            amount: amount,
            blockNumber: block.number
        }));

        if (_pools[poolId].stakedAmount >= _pools[poolId].amountToActive) {
            _pools[poolId].status = DelegateNodeStruct.PoolStatus.ACTIVE;

            emit ActivePool(_pools[poolId]);
        }
    }

    function stake(uint32 poolId) external payable nonReentrant {
        require(msg.value > 0, Errors.INV_ADD);
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        DelegateNodeStruct.PoolInfo memory poolInfo = _pools[poolId];
        require(poolInfo.id > 0, Errors.INV_POOL_ID);
        require(poolInfo.status == DelegateNodeStruct.PoolStatus.INACTIVE, Errors.INV_POOL_ID);
        require(poolInfo.stakedAmount + msg.value <= poolInfo.amountToActive, Errors.INV_STAKE_AMOUNT);

        internalUpdatePoolInfo(poolId, msg.value);
        if (_userPoolInfo[poolId][msg.sender].isStaked == false) {
            _userPoolInfo[poolId][msg.sender].isStaked = true;
            _pools[poolId].stakedUsersSet.push(msg.sender);
        }

        _userPoolInfo[poolId][msg.sender].stakedAmount = _userPoolInfo[poolId][msg.sender].stakedAmount + msg.value;
        emit Stake(msg.sender, msg.value, _pools[poolId]);
    }

    function stakeMultiple(uint32[] calldata poolIds, uint256[] calldata amounts) external payable nonReentrant {
        require(poolIds.length == amounts.length, Errors.INV_ADD);
        uint256 totalAmount = 0;
        for (uint32 i = 0; i < amounts.length; i++) {
            totalAmount = totalAmount + amounts[i];
        }
        require(totalAmount == msg.value, Errors.INV_ADD);

        for (uint32 i = 0; i < poolIds.length; i++) {
            uint32 poolId = poolIds[i];
            uint256 amount = amounts[i];
            require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
            DelegateNodeStruct.PoolInfo memory poolInfo = _pools[poolId];
            require(poolInfo.id > 0, Errors.INV_POOL_ID);
            require(poolInfo.status == DelegateNodeStruct.PoolStatus.INACTIVE, Errors.INV_POOL_ID);
            require(poolInfo.stakedAmount + amount <= poolInfo.amountToActive, Errors.INV_STAKE_AMOUNT);

            internalUpdatePoolInfo(poolId, amount);
            if (_userPoolInfo[poolId][msg.sender].isStaked == false) {
                _userPoolInfo[poolId][msg.sender].isStaked = true;
                _pools[poolId].stakedUsersSet.push(msg.sender);
            }
            _userPoolInfo[poolId][msg.sender].stakedAmount = _userPoolInfo[poolId][msg.sender].stakedAmount + amount;
            emit Stake(msg.sender, amount, _pools[poolId]);
        }
    }

    function updateMinerAddress(uint32 poolId, address minerAddress) external onlyAdminOrModerator {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_GAME_ID);
        require(minerAddress != Errors.ZERO_ADDR, Errors.INV_ADD);
        DelegateNodeStruct.PoolInfo storage poolInfo = _pools[poolId];
        require(poolInfo.id > 0, Errors.INV_POOL_ID);

        poolInfo.minerAddress = minerAddress;
    }

    function adminWithdraw(address to, uint256 amount) external onlyPoolAdmin {
        require(to != Errors.ZERO_ADDR, Errors.INV_ADD);
        require(amount > 0, Errors.INV_ADD);

        payable(to).transfer(amount);
    }

    function safeTransferNative(address _to, uint256 _value) internal {
        (bool success,) = _to.call{value: _value}("");
        if (!success) revert FailedTransfer();
    }

    // only admin can withdraw by poolId
    function adminWithdrawByPoolId(uint32 poolId, address to) external onlyPoolAdmin returns (bool) {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(to != Errors.ZERO_ADDR, Errors.INV_ADD);
        DelegateNodeStruct.PoolInfo storage poolInfo = _pools[poolId];
        require(poolInfo.status == DelegateNodeStruct.PoolStatus.ACTIVE, Errors.INV_ADMIN_WITHDRAW);
        require(poolInfo.stakedAmount == poolInfo.amountToActive, Errors.INV_ADMIN_WITHDRAW); // only allow admin withdraw 1 time to go to run miner

        safeTransferNative(to, poolInfo.amountToActive);

        poolInfo.stakedAmount = 0;
        poolInfo.status = DelegateNodeStruct.PoolStatus.ADMIN_WITHDREW;

        emit AdminWithdraw(to, poolInfo.stakedAmount, poolInfo);
        return true;
    }

    // pool miner receive reward and call this function to contract, contract will receive reward and split to users base on % stake
    function minerReceiveReward(uint32 poolId, uint256 amount) external payable {
        // TODO @kelvin review
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(amount > 0, Errors.INV_ADD);
        DelegateNodeStruct.PoolInfo memory poolInfo = _pools[poolId];
        require(poolInfo.id > 0, Errors.INV_POOL_ID);
        require(poolInfo.minerAddress == msg.sender, Errors.INV_ADD);
        require(poolInfo.status != DelegateNodeStruct.PoolStatus.INACTIVE, Errors.INV_POOL_ID);

        uint256 feeAmount = amount * poolInfo.feePercent / 10_000;
        uint256 rewardAmount = amount - feeAmount;

        for (uint32 i = 0; i < poolInfo.stakedUsersSet.length; i++) {
            address userAddress = poolInfo.stakedUsersSet[i];
            uint256 userStakedAmount = _userPoolInfo[poolId][userAddress].stakedAmount;
            uint256 userReward = userStakedAmount * rewardAmount / poolInfo.stakedAmount;
            _userPoolInfo[poolId][userAddress].rewardAmount = _userPoolInfo[poolId][userAddress].rewardAmount + userReward;
        }
    }

    function userGetRewardAmount(uint32 poolId) external view returns (uint256) {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        return _userPoolInfo[poolId][msg.sender].rewardAmount;
    }

    function userClaimRewardOnPool(uint32 poolId, uint256 amount) external {
        // TODO @kelvin double check
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(amount > 0, Errors.INV_ADD);
        require(_userPoolInfo[poolId][msg.sender].rewardAmount >= amount, Errors.INV_USER_CLAIM_REWARD_AMOUNT);
        _userPoolInfo[poolId][msg.sender].rewardAmount = _userPoolInfo[poolId][msg.sender].rewardAmount - amount;
        _userPoolInfo[poolId][msg.sender].claimedAmount = _userPoolInfo[poolId][msg.sender].claimedAmount + amount;
        safeTransferNative(msg.sender, amount);
    }

//    function unStake(uint32 poolId) external {
//        require(poolId > 0, Errors.INV_ADD);
//        require(poolId < _nextPoolId, Errors.INV_ADD);
//
//        uint256 unStakedAmount = 0;
//        DelegateNodeStruct.StakedInfo[] memory stakedInfos = _pools[poolId].stakedInfos;
//        for (uint32 i = 0; i < stakedInfos.length; i++) {
//            DelegateNodeStruct.StakedInfo memory stakeInfo = stakedInfos[i];
//            if (stakeInfo.user == msg.sender && stakeInfo.amount > 0) {
//                unStakedAmount = unStakedAmount + stakeInfo.amount;
//                stakeInfo.amount = 0;
//            }
//        }
//        require(unStakedAmount > 0, Errors.INV_ADD);
//        require(_pools[poolId].stakedAmount > unStakedAmount, Errors.INV_ADD);
//        _pools[poolId].stakedAmount = _pools[poolId].stakedAmount - unStakedAmount;
//        if (_pools[poolId].stakedAmount < _pools[poolId].amountToActive) {
//            _pools[poolId].status = DelegateNodeStruct.PoolStatus.INACTIVE;
//
//            emit DeActivePool(_pools[poolId]);
//        }
//        uint256 claimedBlock = block.number + _defaultWaitBlock;
//        uint256 oldAmount = _pools[poolId].mapUnStakedInfos[msg.sender].caps[claimedBlock];
//        _pools[poolId].mapUnStakedInfos[msg.sender].caps[claimedBlock] = oldAmount + unStakedAmount;
//        _pools[poolId].mapUnStakedInfos[msg.sender].blocks.push(claimedBlock);
//        emit UnStake(msg.sender, unStakedAmount, poolId, claimedBlock);
//    }
//
//    function claimUnStake(uint32 poolId, uint256 claimedBlock) external payable {
//        require(poolId > 0, Errors.INV_ADD);
//        require(poolId < _nextPoolId, Errors.INV_ADD);
//        require(block.number > claimedBlock, Errors.INV_ADD);
//        uint256 amount = _pools[poolId].mapUnStakedInfos[msg.sender].caps[claimedBlock];
//        require(amount > 0, Errors.INV_ADD);
//        payable(msg.sender).transfer(amount);
//        emit ClaimUnStake(msg.sender, amount, poolId, claimedBlock);
//    }
//
//    function reStakeUnStakedPool(uint32 oldPoolId, uint32 newPoolId) external {
//        require(oldPoolId > 0, Errors.INV_ADD);
//        require(oldPoolId > 0, Errors.INV_ADD);
//        require(newPoolId <= _nextPoolId, Errors.INV_ADD);
//        require(newPoolId <= _nextPoolId, Errors.INV_ADD);
//
//        DelegateNodeStruct.UnStakedInfo storage unStakeInfo = _pools[oldPoolId].mapUnStakedInfos[msg.sender];
//        uint256 unStakedAmount = 0;
//        for (uint32 i = 0; i < unStakeInfo.blocks.length; i++) {
//            unStakedAmount = unStakedAmount + unStakeInfo.caps[unStakeInfo.blocks[i]];
//            unStakeInfo.caps[unStakeInfo.blocks[i]] = 0;
//        }
//        require(unStakedAmount > 0, Errors.INV_ADD);
//        internalUpdatePoolInfo(newPoolId, unStakedAmount);
//        emit ReStakeUnStakedPool(msg.sender, unStakedAmount, oldPoolId, newPoolId);
//    }
}


