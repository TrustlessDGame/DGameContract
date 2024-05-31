// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import {Set} from "../libs/Set.sol";
import {DelegateNodeStorage} from "../storages/DelegateNodeStorage.sol";
import "../libs/helpers/Errors.sol";
import {IWorkerHub} from "../interfaces/IWorkerHub.sol";

contract DelegateNode is
    DelegateNodeStorage,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Set for Set.AddressSet;
    using Set for Set.Uint256Set;

    uint256 private constant PERCENTAGE_DENOMINATOR = 10_000;

    receive() external payable {}

    function initialize(
        address admin,
        address poolAdmin,
        address moderator
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _nextPoolId = 1;
        _admin = admin;
        _poolAdmin = poolAdmin;
        _moderator = moderator;
        _defaultAmountToActive = 25000 * 10 ** 18;
        _defaultPoolFee = 0;
        _defaultWaitBlock = 28 days;
        unstakedReqId = 1;
    }

    modifier onlyAdmin() {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _;
    }

    modifier onlyPoolAdmin() {
        require(msg.sender == _poolAdmin, Errors.ONLY_POOL_ADMIN_ALLOWED);
        _;
    }

    modifier onlyAdminOrModerator() {
        require(
            msg.sender == _admin || msg.sender == _moderator,
            Errors.ONLY_POOL_ADMIN_MODERATOR_ALLOWED
        );
        _;
    }

    function pause() external onlyAdminOrModerator whenNotPaused {
        _pause();
    }

    function unpause() external onlyAdminOrModerator whenPaused {
        _unpause();
    }

    function getUserPoolDetails(
        uint32[] memory poolIds
    ) external view returns (UserPoolInfo[] memory) {
        uint256 poolsLen = poolIds.length;

        UserPoolInfo[] memory userPoolInfos = new UserPoolInfo[](poolsLen);

        for (uint256 i = 0; i < poolsLen; i++) {
            userPoolInfos[i] = _userPoolInfo[poolIds[i]][msg.sender];
        }

        return userPoolInfos;
    }

    function changeAdmin(address newAdm) external onlyAdmin {
        require(newAdm != address(0), Errors.INV_ADD);

        emit AdminChanged(_admin, newAdm);
        _admin = newAdm;
    }

    function changeModerator(address newModerator) external onlyAdmin {
        require(newModerator != address(0), Errors.INV_ADD);

        emit ModeratorChanged(_moderator, newModerator);
        _moderator = newModerator;
    }

    function adminUpdateAmountToActive(
        uint32 poolId,
        uint256 amount
    ) external onlyAdminOrModerator {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        if (amount == 0) revert ZeroAmountToActiveError();

        emit AmountToActiveUpdated(
            msg.sender,
            poolId,
            _pools[poolId].amountToActive,
            amount
        );
        _pools[poolId].amountToActive = amount;
    }

    function adminSetName(
        uint32 poolId,
        string memory name
    ) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);

        emit PoolNameUpdated(poolId, _pools[poolId].name, name);
        _pools[poolId].name = name;
    }

    function adminSetImage(
        uint32 poolId,
        string memory image
    ) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);

        emit PoolImageUpdated(poolId, _pools[poolId].image, image);
        _pools[poolId].image = image;
    }

    function adminChangeFeePercent(
        uint32 poolId,
        uint32 feePercent
    ) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);

        emit PoolFeePercentUpdated(
            poolId,
            _pools[poolId].feePercent,
            feePercent
        );
        _pools[poolId].feePercent = feePercent;
    }

    function addminSetWorkerhubAddress(
        address _workerhubAddr
    ) external onlyAdmin {
        require(_workerhubAddr != address(0), Errors.INV_ADD);
        workerhubAddress = _workerhubAddr;
    }

    function adminCreatePool(uint32 amountPool) external onlyAdminOrModerator {
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

    function _internalUpdateStakingInfo(
        uint32 poolId,
        uint256 amount
    ) internal virtual {
        PoolInfo storage pool = _pools[poolId];

        pool.stakedAmount += amount;
        pool.stakedInfos.push(
            StakedInfo({
                user: msg.sender,
                amount: amount,
                blockNumber: block.number
            })
        );

        UserPoolInfo storage userPoolInfo = _userPoolInfo[poolId][msg.sender];

        if (
            !userPoolInfo.isStaked &&
            !stakedUsersOf[poolId].hasValue(msg.sender)
        ) {
            userPoolInfo.isStaked = true;
            pool.stakedUsersSet.push(msg.sender);

            stakedUsersOf[poolId].insert(msg.sender);
        }

        userPoolInfo.stakedAmount += msg.value;
    }

    function _stake(uint32 _poolId, uint256 _amount) internal {
        require(_amount > 0, Errors.INV_ADD);
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);

        PoolInfo memory poolInfo = _pools[_poolId];
        require(poolInfo.id == _poolId, Errors.INV_POOL_ID);
        if (
            poolInfo.status != PoolStatus.INACTIVE &&
            poolInfo.status != PoolStatus.UNSTAKE_BUFFERING
        ) {
            revert InvalidPoolStatus();
        }

        // if (poolInfo.status != PoolStatus.INACTIVE) {
        //     revert ("Only support stake INACTIVE pool at this moment");
        // }

        _userClaimUnstakedAmount(_poolId);

        uint256 remainingStakeAmount = getRemainingStakeForActivation(_poolId);
        require(_amount <= remainingStakeAmount, Errors.INV_STAKE_AMOUNT);

        if (poolInfo.status == PoolStatus.INACTIVE) {
            _internalUpdateStakingInfo(_poolId, _amount);

            if (_amount == remainingStakeAmount) {
                _pools[_poolId].status = PoolStatus.ACTIVE;
                // delete poolUnstakedInfo[_poolId];
                poolUnstakedInfo[_poolId].firstReqTimestamp = 0;

                emit ActivePool(_pools[_poolId]);
            }
        } else if (poolInfo.status == PoolStatus.UNSTAKE_BUFFERING) {
            if (block.timestamp > poolUnstakedInfo[_poolId].bufferTimeExpireAt)
                revert UnstakeBufferExpire();

            _internalUpdateStakingInfo(_poolId, _amount);

            poolUnstakedInfo[_poolId].reimbursementAmount += _amount;

            if (_amount == remainingStakeAmount) {
                _pools[_poolId].status = PoolStatus.ADMIN_WITHDREW;
                // delete poolUnstakedInfo[_poolId];
                poolUnstakedInfo[_poolId].firstReqTimestamp = 0;

                emit ActivePool(_pools[_poolId]);
            }
        }

        emit Stake(msg.sender, _amount, _pools[_poolId]);
    }

    function stake(uint32 _poolId) public payable nonReentrant whenNotPaused {
        _stake(_poolId, msg.value);
    }

    function stakeMultiple(
        uint32[] calldata _poolIds,
        uint256[] calldata _amounts
    ) external payable nonReentrant whenNotPaused {
        require(_poolIds.length == _amounts.length, Errors.INV_ADD);
        uint256 totalAmount = 0;

        for (uint32 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }

        require(totalAmount == msg.value, Errors.INV_ADD);

        for (uint32 i = 0; i < _poolIds.length; i++) {
            uint32 poolId = _poolIds[i];
            uint256 amount = _amounts[i];
            _stake(poolId, amount);
        }
    }

    function updateMinerAddress(
        uint32 poolId,
        address minerAddress
    ) external onlyAdminOrModerator {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(minerAddress != address(0), Errors.INV_ADD);

        PoolInfo storage poolInfo = _pools[poolId];
        require(poolInfo.id == poolId, Errors.INV_POOL_ID);

        emit MinerAddressUpdated(poolId, poolInfo.minerAddress, minerAddress);

        poolInfo.minerAddress = minerAddress;
    }

    function safeTransferNative(address _to, uint256 _value) internal {
        (bool success, ) = _to.call{value: _value}("");
        if (!success) revert FailedTransfer();
    }

    function adminWithdrawByPoolId(
        uint32 poolId,
        address to
    ) external onlyPoolAdmin nonReentrant whenNotPaused returns (bool) {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(to != address(0), Errors.INV_ADD);

        PoolInfo memory clonedPoolInfo = _pools[poolId];

        require(
            clonedPoolInfo.status == PoolStatus.ACTIVE,
            Errors.INV_ADMIN_WITHDRAW
        );
        require(
            clonedPoolInfo.stakedAmount == clonedPoolInfo.amountToActive,
            Errors.INV_ADMIN_WITHDRAW
        ); // only allow admin withdraw 1 time to go to run miner

        uint256 staked = clonedPoolInfo.stakedAmount;
        _pools[poolId].stakedAmount = 0;
        _pools[poolId].status = PoolStatus.ADMIN_WITHDREW;

        safeTransferNative(to, staked);

        emit AdminWithdrawByPool(to, staked, clonedPoolInfo);
        return true;
    }

    function minerReceiveReward(
        uint32 poolId,
        uint256 amount
    ) external payable whenNotPaused {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(amount > 0, Errors.INV_ADD);

        if (amount != msg.value) revert InvalidTransferedValue();

        PoolInfo memory poolInfo = _pools[poolId];
        require(poolInfo.id == poolId, Errors.INV_POOL_ID);
        require(poolInfo.minerAddress == msg.sender, Errors.INV_ADD);
        require(
            poolInfo.status == PoolStatus.ADMIN_WITHDREW ||
                poolInfo.status == PoolStatus.UNSTAKE_BUFFERING,
            Errors.INV_POOL_STATUS
        );

        uint256 feeAmount = (amount * poolInfo.feePercent) /
            PERCENTAGE_DENOMINATOR;
        uint256 rewardAmount = amount - feeAmount;
        uint256 len = stakedUsersOf[poolId].values.length;

        for (uint32 i = 0; i < len; i++) {
            address userAddress = stakedUsersOf[poolId].at(i);
            uint256 userStakedAmount = _userPoolInfo[poolId][userAddress]
                .stakedAmount;
            uint256 userReward = (userStakedAmount * rewardAmount) /
                poolInfo.amountToActive;
            _userPoolInfo[poolId][userAddress].rewardAmount += userReward;
            _userInfo[userAddress].totalReward += userReward;

            emit UserReceiveRewardFromMiner(userAddress, poolId, userReward);
        }

        emit MinerReceiveReward(msg.sender, poolId, amount, feeAmount);
    }

    function userGetRewardAmount(
        uint32 poolId,
        address caller
    ) external view returns (uint256) {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(caller != address(0), Errors.INV_ADD);
        return _userPoolInfo[poolId][caller].rewardAmount;
    }

    function userClaimRewardOnPool(
        uint32 poolId,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(
            0 < amount &&
                amount <= _userPoolInfo[poolId][msg.sender].rewardAmount,
            Errors.INV_USER_CLAIM_REWARD_AMOUNT
        );

        _userPoolInfo[poolId][msg.sender].rewardAmount -= amount;
        _userPoolInfo[poolId][msg.sender].claimedAmount += amount;
        _userInfo[msg.sender].totalReward -= amount;
        _userInfo[msg.sender].totalClaimed += amount;

        safeTransferNative(msg.sender, amount);

        emit UserClaimReward(msg.sender, poolId, amount);
    }

    function userClaimFullRewardOnPool(
        uint32 poolId
    ) external nonReentrant whenNotPaused {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);

        UserPoolInfo storage userPoolInfo = _userPoolInfo[poolId][msg.sender];
        uint256 amount = userPoolInfo.rewardAmount;

        if (amount == 0) {
            revert NoRewardToClaim();
        }

        userPoolInfo.rewardAmount = 0;
        userPoolInfo.claimedAmount += amount;
        _userInfo[msg.sender].totalReward -= amount;
        _userInfo[msg.sender].totalClaimed += amount;

        safeTransferNative(msg.sender, amount);

        emit UserClaimReward(msg.sender, poolId, amount);
    }

    function getWorkerHubUnstakeDelayTime() public view returns (uint40) {
        return IWorkerHub(workerhubAddress).unstakeDelayTime();
    }

    function isAvailableToUnstake(
        uint32 _poolId,
        address _caller
    ) public view returns (bool) {
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);

        PoolStatus poolStatus = _pools[_poolId].status;

        if (
            poolStatus != PoolStatus.INACTIVE &&
            poolStatus != PoolStatus.ADMIN_WITHDREW &&
            poolStatus != PoolStatus.UNSTAKE_BUFFERING &&
            poolStatus != PoolStatus.WAIT_ADMIN_RETURNED_FUND
        ) return false;

        if (
            !(userUnstakeReqIds[_poolId][_caller].isEmpty() &&
                _userPoolInfo[_poolId][_caller].isStaked)
        ) return false;

        return true;
    }

    function unstake(uint32 _poolId) public nonReentrant whenNotPaused {
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);
        PoolStatus poolStatus = _pools[_poolId].status;

        if (
            poolStatus != PoolStatus.INACTIVE &&
            poolStatus != PoolStatus.ADMIN_WITHDREW &&
            poolStatus != PoolStatus.UNSTAKE_BUFFERING &&
            poolStatus != PoolStatus.WAIT_ADMIN_RETURNED_FUND
        ) revert InvalidPoolStatus();

        uint256 unstakeAmount = _userPoolInfo[_poolId][msg.sender].stakedAmount;

        if (unstakeAmount == 0) revert ZeroStakedAmountError();
        if (
            userWannaUnstakeAmount[_poolId][msg.sender] == unstakeAmount ||
            userWannaUnstakeAmount[_poolId][msg.sender] > 0
        ) revert UnstakeAlreadyCalled();

        _userPoolInfo[_poolId][msg.sender].isStaked = false;

        uint256 reqId = unstakedReqId++;
        uint40 firstUnstakeTimestamp = uint40(
            poolUnstakedInfo[_poolId].firstReqTimestamp != 0
                ? poolUnstakedInfo[_poolId].firstReqTimestamp
                : block.timestamp
        );

        unstakeClaimableTime[reqId] =
            firstUnstakeTimestamp +
            defaultUnstakeBufferTime +
            getWorkerHubUnstakeDelayTime();
        unstakedReqInfo[reqId] = UnstakedReqInfo(
            _poolId,
            msg.sender,
            unstakeAmount,
            uint40(block.timestamp)
        );
        stakedUsersOf[_poolId].erase(msg.sender);

        bool isFirstUnstake = false;
        if (poolStatus == PoolStatus.INACTIVE) {
            _userPoolInfo[_poolId][msg.sender].stakedAmount = 0;
            userWannaUnstakeAmount[_poolId][msg.sender] = 0;
            _pools[_poolId].stakedAmount -= unstakeAmount;
            _userInfo[msg.sender].reserve1 += unstakeAmount;

            safeTransferNative(msg.sender, unstakeAmount);
        } else if (
            poolStatus == PoolStatus.ADMIN_WITHDREW ||
            poolStatus == PoolStatus.UNSTAKE_BUFFERING ||
            poolStatus == PoolStatus.WAIT_ADMIN_RETURNED_FUND
        ) {
            userUnstakeReqIds[_poolId][msg.sender].insert(reqId);
            poolUnstakeReqIds[_poolId].insert(reqId);
            userWannaUnstakeAmount[_poolId][msg.sender] += unstakeAmount;

            if (poolStatus == PoolStatus.ADMIN_WITHDREW) {
                _pools[_poolId].status = PoolStatus.UNSTAKE_BUFFERING;

                isFirstUnstake = true;
                uint40 bufferingTimeExpireAt = uint40(
                    block.timestamp + defaultUnstakeBufferTime
                );

                poolUnstakedInfo[_poolId] = PoolUnstakedInfo({
                    firstReqTimestamp: uint40(block.timestamp),
                    bufferTimeExpireAt: bufferingTimeExpireAt,
                    totalUnstakedAmount: poolUnstakedInfo[_poolId]
                        .totalUnstakedAmount + unstakeAmount,
                    reimbursementAmount: 0
                });
            } else {
                poolUnstakedInfo[_poolId].totalUnstakedAmount += unstakeAmount;
            }
        }

        emit UserUnstake(
            msg.sender,
            _poolId,
            UserUnstakeEventInfo(
                unstakeAmount,
                reqId,
                _pools[_poolId].status,
                uint40(block.timestamp),
                isFirstUnstake
            )
        );
    }

    function getRestakeableAmount(
        uint32 _poolId,
        address _caller
    ) public view returns (uint256) {
        uint256 unstakedAmount = userWannaUnstakeAmount[_poolId][_caller];
        uint256 remainingStakeAmount = getRemainingStakeForActivation(_poolId);
        uint256 restakeableAmount = remainingStakeAmount >= unstakedAmount
            ? unstakedAmount
            : remainingStakeAmount;

        return restakeableAmount;
    }

    function restake(uint32 _poolId) public {
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);
        if (_pools[_poolId].status != PoolStatus.UNSTAKE_BUFFERING)
            revert InvalidPoolStatus();
        if (block.timestamp > poolUnstakedInfo[_poolId].bufferTimeExpireAt)
            revert PrematureRestake();
        //Check msg sender has already staked
        // if (_userPoolInfo[_poolId][msg.sender].isStaked)
        //     revert("The user is still staking");
        // ==> Allow restake multiple time

        uint256 reqId = userUnstakeReqIds[_poolId][msg.sender].at(0);
        if (unstakedReqInfo[reqId].unstaker != msg.sender)
            revert("Invalid unstaker");

        uint256 unstakedAmount = userWannaUnstakeAmount[_poolId][msg.sender];
        if (unstakedAmount == 0) revert("Zero unstake amount");

        uint256 remainingStakeAmount = getRemainingStakeForActivation(_poolId);
        uint256 restakeableAmount = remainingStakeAmount >= unstakedAmount
            ? unstakedAmount
            : remainingStakeAmount;
        if (restakeableAmount == 0) revert("Zero restakeable amount");

        userWannaUnstakeAmount[_poolId][msg.sender] -= restakeableAmount;
        unstakedReqInfo[reqId].amount -= restakeableAmount;
        poolUnstakedInfo[_poolId].totalUnstakedAmount -= restakeableAmount;

        // If user restake all the staked amount, we remove the unstake request id from the unstake queue
        if (restakeableAmount == unstakedAmount) {
            // Remove unstake queue of user and pool
            userUnstakeReqIds[_poolId][msg.sender].erase(reqId);
            poolUnstakeReqIds[_poolId].erase(reqId);
        }
        //add user to the staked user list (keep track reward)
        if (!stakedUsersOf[_poolId].hasValue(msg.sender)) {
            stakedUsersOf[_poolId].insert(msg.sender);
        }
        _userPoolInfo[_poolId][msg.sender].isStaked = true;
        _userPoolInfo[_poolId][msg.sender].stakedAmount += restakeableAmount;

        //Compare total unstake amount to reimbursement amount, resolve unstake to start the calculating reward
        // uint256 remainingStakeAmount = getRemainingStakeForActivation(_poolId);
        if (getRemainingStakeForActivation(_poolId) == 0) {
            _pools[_poolId].status = PoolStatus.ADMIN_WITHDREW;
            poolUnstakedInfo[_poolId].firstReqTimestamp = 0;

            emit ActivePool(_pools[_poolId]);
        }

        emit UserRestake(
            msg.sender,
            _poolId,
            restakeableAmount,
            userWannaUnstakeAmount[_poolId][msg.sender]
        );
    }

    function getRemainingStakeForActivation(
        uint32 _poolId
    ) public view returns (uint256) {
        if (_poolId >= _nextPoolId) revert InvalidPoolId();

        uint256 amountToActive = _pools[_poolId].amountToActive;
        uint256 totalUnstake = poolUnstakedInfo[_poolId].totalUnstakedAmount;
        uint256 poolBalance = _pools[_poolId].stakedAmount;

        if (
            _pools[_poolId].status == PoolStatus.INACTIVE ||
            _pools[_poolId].status == PoolStatus.ACTIVE
        ) {
            return amountToActive - (poolBalance - totalUnstake);
        } else if (
            _pools[_poolId].status == PoolStatus.UNSTAKE_BUFFERING ||
            _pools[_poolId].status == PoolStatus.WAIT_ADMIN_RETURNED_FUND
        ) {
            return totalUnstake - poolBalance; //always greater or equal 0
        }

        return 0;
    }

    function resolveUnstake(uint32 _poolId) public {
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);
        if (block.timestamp < poolUnstakedInfo[_poolId].bufferTimeExpireAt)
            revert PrematureResolveUnstake();

        if (_pools[_poolId].status != PoolStatus.UNSTAKE_BUFFERING) {
            emit ResolveUnstake(msg.sender, _poolId, _pools[_poolId].status);
            return;
        }

        uint256 remainingStakeAmount = getRemainingStakeForActivation(_poolId);

        if (remainingStakeAmount == 0) {
            _pools[_poolId].status = PoolStatus.ADMIN_WITHDREW;
            // delete poolUnstakedInfo[_poolId];
            poolUnstakedInfo[_poolId].firstReqTimestamp = 0;
        } else if (remainingStakeAmount > 0) {
            _pools[_poolId].status = PoolStatus.WAIT_ADMIN_RETURNED_FUND;
        }

        emit ResolveUnstake(msg.sender, _poolId, _pools[_poolId].status);
    }

    function _userClaimUnstakedAmount(uint32 _poolId) internal {
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);

        if (userUnstakeReqIds[_poolId][msg.sender].size() == 0) {
            return;
        }

        uint256 userUnstakeReqId = userUnstakeReqIds[_poolId][msg.sender].at(0);
        if (
            poolUnstakeReqIds[_poolId].hasValue(userUnstakeReqId) &&
            userUnstakeReqIds[_poolId][msg.sender].hasValue(userUnstakeReqId)
        ) {
            poolUnstakeReqIds[_poolId].erase(userUnstakeReqId);
            userUnstakeReqIds[_poolId][msg.sender].erase(userUnstakeReqId);
        }

        if (block.timestamp < unstakeClaimableTime[userUnstakeReqId])
            revert PrematureClaimUnstake();

        uint256 claimableAmount = userWannaUnstakeAmount[_poolId][msg.sender];
        if (claimableAmount == 0) return;

        _userPoolInfo[_poolId][msg.sender].stakedAmount -= claimableAmount;
        userWannaUnstakeAmount[_poolId][msg.sender] = 0;
        _pools[_poolId].stakedAmount -= claimableAmount;
        _userInfo[msg.sender].reserve1 += claimableAmount;

        // In the case the reimbursement amount is equal the total unstaked amount, the poolUnstakedInfo will be deleted
        if (poolUnstakedInfo[_poolId].totalUnstakedAmount != 0) {
            poolUnstakedInfo[_poolId].totalUnstakedAmount -= claimableAmount;
        }

        safeTransferNative(msg.sender, claimableAmount);

        emit UserClaimUnstakedAmount(msg.sender, _poolId, claimableAmount);
    }

    function userClaimUnstakedAmount(
        uint32 _poolId
    ) public nonReentrant whenNotPaused {
        _userClaimUnstakedAmount(_poolId);
    }

    function minerRefundPoolBalance(
        uint32 _poolId
    ) external payable whenNotPaused {
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);
        if (_pools[_poolId].status != PoolStatus.WAIT_ADMIN_RETURNED_FUND)
            revert InvalidPoolStatus();
        if (
            block.timestamp <
            poolUnstakedInfo[_poolId].bufferTimeExpireAt +
                getWorkerHubUnstakeDelayTime()
        ) revert PrematureMinerRefundPool();

        address poolMiner = _pools[_poolId].minerAddress;
        uint256 refundValue = _pools[_poolId].amountToActive;
        if (msg.sender != poolMiner) revert SenderNotPoolMiner();
        if (msg.value != refundValue) revert RefundedValueNotEnough();

        _pools[_poolId].stakedAmount += msg.value;
        _pools[_poolId].status = PoolStatus.INACTIVE;

        emit MinerRefundPoolBalance(poolMiner, _poolId, refundValue);
    }

    function setDefaultUnstakeBufferTime(
        uint40 _amountInSecond
    ) external onlyAdmin {
        require(_amountInSecond > 0, Errors.INV_ADD);

        emit DefaultUnstakeBufferTimeUpdate(
            msg.sender,
            defaultUnstakeBufferTime,
            _amountInSecond
        );
        defaultUnstakeBufferTime = _amountInSecond;
    }

    function getUserUnstakeReqIds(
        uint32 _poolId,
        address _user
    ) public view returns (uint256[] memory) {
        return userUnstakeReqIds[_poolId][_user].values;
    }

    function getPoolUnstakeReqIds(
        uint32 _poolId
    ) public view returns (uint256[] memory) {
        return (poolUnstakeReqIds[_poolId].values);
    }

    function getStakedUsersOf(
        uint32 _poolId
    ) public view returns (address[] memory) {
        return stakedUsersOf[_poolId].values;
    }
}
