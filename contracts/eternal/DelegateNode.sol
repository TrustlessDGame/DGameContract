// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

// DelegateNode contract is similar to staking contract, allow users stake $EAI, if enough $EAI staked, backend will manually start a miner
// Miner run something outside login and earn reward, then reward will be split to users
// mean a user dont have enough $EAI to run a miner, they stake with other people to run a miner
// Contract is upgradeable and keep track about stake info (address, amount, block_time, etc)
// Will create pool to receive $EAI stake from user
// We have some pools (similar to ERC-721), each pools have different state: id, status, staked amount

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import {DelegateNodeStorage} from "../storages/DelegateNodeStorage.sol";
import "../libs/helpers/Errors.sol";

contract DelegateNode is DelegateNodeStorage, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    uint256 constant private PERCENTAGE_DENOMINATOR = 10_000;

    receive() external payable {}

    function initialize(
        address admin,
        address poolAdmin,
        address moderator
    ) initializer external {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _nextPoolId = 1;
        _admin = admin;
        _poolAdmin = poolAdmin;
        _moderator = moderator;
        _defaultAmountToActive = 100 * 10 ** 18;
        _defaultPoolFee = 1000;
        _defaultWaitBlock = 1;
    }

    // modifier admin only
    modifier onlyAdmin() {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _;
    }

    modifier onlyPoolAdmin() {
        require(msg.sender == _poolAdmin, Errors.ONLY_POOL_ADMIN_ALLOWED);
        _;
    }

    modifier onlyAdminOrModerator() {
        require(msg.sender == _admin || msg.sender == _moderator, Errors.ONLY_POOL_ADMIN_MODERATOR_ALLOWED);
        _;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function changeAdmin(address newAdm) external onlyAdmin {
        require(newAdm != address(0), Errors.ONLY_ADMIN_ALLOWED);

        emit AdminChanged(_admin, newAdm);
        _admin = newAdm;
    }

    function changeModerator(address newModerator) external onlyAdmin {
        require(newModerator != address(0), Errors.ONLY_ADMIN_ALLOWED);

        emit ModeratorChanged(_moderator, newModerator);
        _moderator = newModerator;
    }

    function adminUpdateAmountToActive(uint32 poolId, uint256 amount) external onlyAdminOrModerator {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_GAME_ID);
        require(amount > 0, Errors.INV_ADD);

        emit AmountToActiveupdated(msg.sender, poolId, _pools[poolId].amountToActive, amount);
        _pools[poolId].amountToActive = amount;
    }

    function adminSetName(uint32 poolId, string memory name) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_GAME_ID);

        emit PoolNameUpdated(poolId, _pools[poolId].name, name);
        _pools[poolId].name = name;
    }

    function adminSetImage(uint32 poolId, string memory image) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_GAME_ID);

        emit PoolImageUpdated(poolId, _pools[poolId].image, image);
        _pools[poolId].image = image;
    }

    function adminChangeFeePercent(uint32 poolId, uint32 feePercent) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_GAME_ID);
        require(feePercent > 0, Errors.INV_ADD);

        emit PoolFeePercentUpdated(poolId, _pools[poolId].feePercent, feePercent);
        _pools[poolId].feePercent = feePercent;
    }

    function adminCreatePool(uint32 amountPool) external onlyAdminOrModerator {
        // loop to PRE-CREATE pool; amountPool is number of pool want to pre-create
        for (uint32 i = 0; i < amountPool; i++) {
            PoolInfo storage pool = _pools[_nextPoolId];
            pool.status = PoolStatus.INACTIVE;
            pool.id = _nextPoolId;
            pool.amountToActive = _defaultAmountToActive;
            pool.stakedAmount = 0;
            pool.feePercent = _defaultPoolFee;

            _nextPoolId += 1;
            emit CreatePool(_pools[pool.id]);
        }
    }

    function _internalUpdatePoolInfo(uint32 poolId, uint256 amount) internal virtual {
        // update pool info
        PoolInfo storage pool = _pools[poolId];

        pool.stakedAmount += amount;
        pool.stakedInfos.push(StakedInfo({
            user: msg.sender,
            amount: amount,
            blockNumber: block.number
        }));

        if (pool.stakedAmount >= pool.amountToActive) {
            pool.status = PoolStatus.ACTIVE;

            emit ActivePool(pool);
        }
    }

    function stakeNeededToActivate(uint32 poolId) public view returns(uint256) {
        if (poolId >= _nextPoolId) revert InvalidPoolId();

        return _pools[poolId].amountToActive - _pools[poolId].stakedAmount;
    }

    function stake(uint32 poolId) external payable whenNotPaused {
        require(msg.value > 0, Errors.INV_ADD);
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);

        PoolInfo memory poolInfo = _pools[poolId];
        require(poolInfo.id == poolId, Errors.INV_POOL_ID);
        require(poolInfo.status == PoolStatus.INACTIVE, Errors.INV_POOL_ID);
        require(poolInfo.stakedAmount + msg.value <= poolInfo.amountToActive, Errors.INV_STAKE_AMOUNT);

        _internalUpdatePoolInfo(poolId, msg.value);

        if (_userPoolInfo[poolId][msg.sender].isStaked == false) {
            _userPoolInfo[poolId][msg.sender].isStaked = true;
            _pools[poolId].stakedUsersSet.push(msg.sender);
        }

        _userPoolInfo[poolId][msg.sender].stakedAmount += msg.value;

        emit Stake(msg.sender, msg.value, _pools[poolId]);
    }

    function stakeMultiple(uint32[] calldata poolIds, uint256[] calldata amounts) external payable whenNotPaused {
        require(poolIds.length == amounts.length, Errors.INV_ADD);
        uint256 totalAmount = 0;

        for (uint32 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(totalAmount == msg.value, Errors.INV_ADD);

        for (uint32 i = 0; i < poolIds.length; i++) {
            uint32 poolId = poolIds[i];
            uint256 amount = amounts[i];
            require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);

            PoolInfo memory poolInfo = _pools[poolId];
            require(poolInfo.id == poolId, Errors.INV_POOL_ID);
            require(poolInfo.status == PoolStatus.INACTIVE, Errors.INV_POOL_ID);
            require(poolInfo.stakedAmount + amount <= poolInfo.amountToActive, Errors.INV_STAKE_AMOUNT);

            _internalUpdatePoolInfo(poolId, amount);

            if (_userPoolInfo[poolId][msg.sender].isStaked == false) {
                _userPoolInfo[poolId][msg.sender].isStaked = true;
                _pools[poolId].stakedUsersSet.push(msg.sender);
            }
            _userPoolInfo[poolId][msg.sender].stakedAmount += amount;

            emit Stake(msg.sender, amount, _pools[poolId]);
        }
    }

    function updateMinerAddress(uint32 poolId, address minerAddress) external onlyAdminOrModerator {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_GAME_ID);
        require(minerAddress != address(0), Errors.INV_ADD);

        PoolInfo storage poolInfo = _pools[poolId];
        require(poolInfo.id == poolId, Errors.INV_POOL_ID);

        emit MinerAddressUpdated(poolId, poolInfo.minerAddress, minerAddress);

        poolInfo.minerAddress = minerAddress;
    }

    //TODO: kelvin check again
    function adminWithdraw(address to, uint256 amount) external onlyPoolAdmin nonReentrant whenNotPaused {
        require(to != address(0), Errors.INV_ADD);
        require(amount > 0, Errors.INV_ADD);

        safeTransferNative(to, amount);
    }

    function safeTransferNative(address _to, uint256 _value) internal {
        (bool success,) = _to.call{value: _value}("");
        if (!success) revert FailedTransfer();
    }

    // only admin can withdraw by poolId
    function adminWithdrawByPoolId(uint32 poolId, address to) external onlyPoolAdmin nonReentrant whenNotPaused returns (bool) {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(to != address(0), Errors.INV_ADD);

        PoolInfo storage poolInfo = _pools[poolId];
        require(poolInfo.status == PoolStatus.ACTIVE, Errors.INV_ADMIN_WITHDRAW);
        require(poolInfo.stakedAmount == poolInfo.amountToActive, Errors.INV_ADMIN_WITHDRAW); // only allow admin withdraw 1 time to go to run miner

        uint256 staked = poolInfo.stakedAmount;
        poolInfo.stakedAmount = 0;
        poolInfo.status = PoolStatus.ADMIN_WITHDREW;

        safeTransferNative(to, staked);

        emit AdminWithdraw(to, poolInfo.stakedAmount, poolInfo);
        return true;
    }

    // pool miner receive reward and call this function to contract, contract will receive reward and split to users base on % stake
    function minerReceiveReward(uint32 poolId, uint256 amount) external payable whenNotPaused {
        // TODO @kelvin review
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(amount > 0, Errors.INV_ADD);
        if (amount != msg.value) revert InvalidTransferedValue();

        PoolInfo memory poolInfo = _pools[poolId];
        require(poolInfo.id == poolId, Errors.INV_POOL_ID);
        require(poolInfo.minerAddress == msg.sender, Errors.INV_ADD);
        require(poolInfo.status != PoolStatus.INACTIVE, Errors.INV_POOL_ID);

        uint256 feeAmount = amount * poolInfo.feePercent / PERCENTAGE_DENOMINATOR;
        uint256 rewardAmount = amount - feeAmount;

        for (uint32 i = 0; i < poolInfo.stakedUsersSet.length; i++) {
            address userAddress = poolInfo.stakedUsersSet[i];
            uint256 userStakedAmount = _userPoolInfo[poolId][userAddress].stakedAmount;
            uint256 userReward = userStakedAmount * rewardAmount / poolInfo.stakedAmount;
            _userPoolInfo[poolId][userAddress].rewardAmount += userReward;
        }

        emit MinerReceiveReward(msg.sender, poolId, amount);
    }

    function userGetRewardAmount(uint32 poolId) external view returns (uint256) {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        return _userPoolInfo[poolId][msg.sender].rewardAmount;
    }

    function userClaimRewardOnPool(uint32 poolId, uint256 amount) external nonReentrant whenNotPaused {
        // TODO @kelvin double check
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(amount > 0, Errors.INV_ADD);
        require(_userPoolInfo[poolId][msg.sender].rewardAmount >= amount, Errors.INV_USER_CLAIM_REWARD_AMOUNT);

        _userPoolInfo[poolId][msg.sender].rewardAmount -= amount;
        _userPoolInfo[poolId][msg.sender].claimedAmount += amount;
        
        safeTransferNative(msg.sender, amount);

        emit UserClaimReward(msg.sender, poolId, amount);
    }

//    function unStake(uint32 poolId) external {
//        require(poolId > 0, Errors.INV_ADD);
//        require(poolId < _nextPoolId, Errors.INV_ADD);
//
//        uint256 unStakedAmount = 0;
//        StakedInfo[] memory stakedInfos = _pools[poolId].stakedInfos;
//        for (uint32 i = 0; i < stakedInfos.length; i++) {
//            StakedInfo memory stakeInfo = stakedInfos[i];
//            if (stakeInfo.user == msg.sender && stakeInfo.amount > 0) {
//                unStakedAmount = unStakedAmount + stakeInfo.amount;
//                stakeInfo.amount = 0;
//            }
//        }
//        require(unStakedAmount > 0, Errors.INV_ADD);
//        require(_pools[poolId].stakedAmount > unStakedAmount, Errors.INV_ADD);
//        _pools[poolId].stakedAmount = _pools[poolId].stakedAmount - unStakedAmount;
//        if (_pools[poolId].stakedAmount < _pools[poolId].amountToActive) {
//            _pools[poolId].status = PoolStatus.INACTIVE;
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
//        UnStakedInfo storage unStakeInfo = _pools[oldPoolId].mapUnStakedInfos[msg.sender];
//        uint256 unStakedAmount = 0;
//        for (uint32 i = 0; i < unStakeInfo.blocks.length; i++) {
//            unStakedAmount = unStakedAmount + unStakeInfo.caps[unStakeInfo.blocks[i]];
//            unStakeInfo.caps[unStakeInfo.blocks[i]] = 0;
//        }
//        require(unStakedAmount > 0, Errors.INV_ADD);
//        _internalUpdatePoolInfo(newPoolId, unStakedAmount);
//        emit ReStakeUnStakedPool(msg.sender, unStakedAmount, oldPoolId, newPoolId);
//    }
}


