// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import {Set} from "../libs/Set.sol";
import {DelegateNodeStorage} from "../storages/DelegateNodeStorage.sol";
import "../libs/helpers/Errors.sol";
import {IWorkerHub} from "../interfaces/IWorkerHub.sol";

contract DelegateNode is DelegateNodeStorage, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using Set for Set.AddressSet;
    using Set for Set.Uint256Set;

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
        _defaultAmountToActive = 25000 * 10 ** 18;
        _defaultPoolFee = 0;
        _defaultWaitBlock = 28 days;
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

    function pause() external onlyAdminOrModerator whenNotPaused {
        _pause();
    }

    function unpause() external onlyAdminOrModerator whenPaused {
        _unpause();
    }

    function getUserPoolDetails(uint32[] memory poolIds) external view returns(UserPooInfo[] memory) {
        uint256 poolsLen = poolIds.length;

        UserPooInfo[] memory userPoolInfos = new UserPooInfo[](poolsLen);

        for (uint256 i = 0; i < poolsLen; i++) {
            userPoolInfos[i] = _userPoolInfo[poolIds[i]][msg.sender];
        }

        return userPoolInfos;
    }

    function getRemainingStakeForActivation(uint32 poolId) public view returns(uint256) {
        if (poolId >= _nextPoolId) revert InvalidPoolId();

        return _pools[poolId].amountToActive - _pools[poolId].stakedAmount;
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

    function adminUpdateAmountToActive(uint32 poolId, uint256 amount) external onlyAdminOrModerator {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        if (amount == 0) revert AmountToActiveZeroError();

        emit AmountToActiveUpdated(msg.sender, poolId, _pools[poolId].amountToActive, amount);
        _pools[poolId].amountToActive = amount;
    }

    function adminSetName(uint32 poolId, string memory name) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);

        emit PoolNameUpdated(poolId, _pools[poolId].name, name);
        _pools[poolId].name = name;
    }

    function adminSetImage(uint32 poolId, string memory image) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);

        emit PoolImageUpdated(poolId, _pools[poolId].image, image);
        _pools[poolId].image = image;
    }

    function adminChangeFeePercent(uint32 poolId, uint32 feePercent) external onlyAdmin {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);

        emit PoolFeePercentUpdated(poolId, _pools[poolId].feePercent, feePercent);
        _pools[poolId].feePercent = feePercent;
    }

    function addminSetWorkerhubAddress(address _workerhubAddr) external onlyAdmin {
        require(_workerhubAddr != address(0), Errors.INV_ADD);

        //TODO add event
        workerhubAddress = _workerhubAddr;
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

    function _stake(uint32 _poolId) internal {

    }

    function stake(uint32 poolId) external payable whenNotPaused {
        require(msg.value > 0, Errors.INV_ADD);
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);

        PoolInfo memory poolInfo = _pools[poolId];
        require(poolInfo.id == poolId, Errors.INV_POOL_ID);
        require(poolInfo.status == PoolStatus.INACTIVE, Errors.INV_POOL_ID);
        require(poolInfo.stakedAmount + msg.value <= poolInfo.amountToActive, Errors.INV_STAKE_AMOUNT);

        _internalUpdatePoolInfo(poolId, msg.value);

        if (!_userPoolInfo[poolId][msg.sender].isStaked && !stakedUsersOf[poolId].hasValue(msg.sender)) {
            _userPoolInfo[poolId][msg.sender].isStaked = true;
            _pools[poolId].stakedUsersSet.push(msg.sender);

            stakedUsersOf[poolId].insert(msg.sender);
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

            if (!_userPoolInfo[poolId][msg.sender].isStaked && !stakedUsersOf[poolId].hasValue(msg.sender)) {
                _userPoolInfo[poolId][msg.sender].isStaked = true;
                _pools[poolId].stakedUsersSet.push(msg.sender);

                stakedUsersOf[poolId].insert(msg.sender);
            }

            _userPoolInfo[poolId][msg.sender].stakedAmount += amount;

            emit Stake(msg.sender, amount, _pools[poolId]);
        }
    }

    function updateMinerAddress(uint32 poolId, address minerAddress) external onlyAdminOrModerator {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(minerAddress != address(0), Errors.INV_ADD);

        PoolInfo storage poolInfo = _pools[poolId];
        require(poolInfo.id == poolId, Errors.INV_POOL_ID);

        emit MinerAddressUpdated(poolId, poolInfo.minerAddress, minerAddress);

        poolInfo.minerAddress = minerAddress;
    }

    function adminWithdraw(address to, uint256 amount) external onlyPoolAdmin nonReentrant whenNotPaused {
        require(to != address(0), Errors.INV_ADD);
        require(0 < amount && amount <= address(this).balance, Errors.INV_ADMIN_WITHDRAW);

        safeTransferNative(to, amount);

        emit AdminWithdraw(to, amount);
    }

    function safeTransferNative(address _to, uint256 _value) internal {
        (bool success,) = _to.call{value: _value}("");
        if (!success) revert FailedTransfer();
    }

    // only admin can withdraw by poolId
    function adminWithdrawByPoolId(uint32 poolId, address to) external onlyPoolAdmin nonReentrant whenNotPaused returns (bool) {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(to != address(0), Errors.INV_ADD);

        PoolInfo memory clonedPoolInfo = _pools[poolId];

        require(clonedPoolInfo.status == PoolStatus.ACTIVE, Errors.INV_ADMIN_WITHDRAW);
        require(clonedPoolInfo.stakedAmount == clonedPoolInfo.amountToActive, Errors.INV_ADMIN_WITHDRAW); // only allow admin withdraw 1 time to go to run miner

        uint256 staked = clonedPoolInfo.stakedAmount;
        _pools[poolId].stakedAmount = 0;
        _pools[poolId].status = PoolStatus.ADMIN_WITHDREW;

        safeTransferNative(to, staked);

        emit AdminWithdrawByPool(to, staked, clonedPoolInfo);
        return true;
    }

    // pool miner receive reward and call this function to contract, contract will receive reward and split to users base on % stake
    function minerReceiveReward(uint32 poolId, uint256 amount) external payable whenNotPaused {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(amount > 0, Errors.INV_ADD);

        if (amount != msg.value) revert InvalidTransferedValue();

        PoolInfo memory poolInfo = _pools[poolId];
        require(poolInfo.id == poolId, Errors.INV_POOL_ID);
        require(poolInfo.minerAddress == msg.sender, Errors.INV_ADD);
        require(poolInfo.status == PoolStatus.ADMIN_WITHDREW, Errors.INV_POOL_STATUS);

        uint256 feeAmount = amount * poolInfo.feePercent / PERCENTAGE_DENOMINATOR;
        uint256 rewardAmount = amount - feeAmount;

        for (uint32 i = 0; i < poolInfo.stakedUsersSet.length; i++) {
            address userAddress = poolInfo.stakedUsersSet[i];
            uint256 userStakedAmount = _userPoolInfo[poolId][userAddress].stakedAmount;
            uint256 userReward = userStakedAmount * rewardAmount / poolInfo.amountToActive;
            _userPoolInfo[poolId][userAddress].rewardAmount += userReward;
            _userInfo[userAddress].totalReward += userReward;

            emit UserReceiveRewardFromMiner(userAddress, poolId, userReward);
        }

        emit MinerReceiveReward(msg.sender, poolId, amount, feeAmount);
    }

    function userGetRewardAmount(uint32 poolId, address caller) external view returns (uint256) {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(caller != address(0), Errors.INV_ADD);
        return _userPoolInfo[poolId][caller].rewardAmount;
    }

    function userClaimRewardOnPool(uint32 poolId, uint256 amount) external nonReentrant whenNotPaused {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        require(0 < amount && amount <= _userPoolInfo[poolId][msg.sender].rewardAmount, Errors.INV_USER_CLAIM_REWARD_AMOUNT);

        _userPoolInfo[poolId][msg.sender].rewardAmount -= amount;
        _userPoolInfo[poolId][msg.sender].claimedAmount += amount;
        _userInfo[msg.sender].totalReward -= amount;
        _userInfo[msg.sender].totalClaimed += amount;

        safeTransferNative(msg.sender, amount);

        emit UserClaimReward(msg.sender, poolId, amount);
    }

    function userClaimFullRewardOnPool(uint32 poolId) external nonReentrant whenNotPaused {
        require(poolId > 0 && poolId < _nextPoolId, Errors.INV_POOL_ID);
        uint256 amount = _userPoolInfo[poolId][msg.sender].rewardAmount;
        if (amount == 0) {
            revert NoRewardToClaim();
        }

        _userPoolInfo[poolId][msg.sender].rewardAmount = 0;
        _userPoolInfo[poolId][msg.sender].claimedAmount += amount;
        _userInfo[msg.sender].totalReward -= amount;
        _userInfo[msg.sender].totalClaimed += amount;

        safeTransferNative(msg.sender, amount);

        emit UserClaimReward(msg.sender, poolId, amount);
    }

    function getWorkerHubUnstakeDelayTime() public view returns(uint40) {
        return IWorkerHub(workerhubAddress).unstakeDelayTime();
    }

    function unstake(uint32 _poolId) public nonReentrant {
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);
        // 1. kiem tra trang thai -> back lai sau
        if (_pools[_poolId].status != PoolStatus.INACTIVE &&
            _pools[_poolId].status != PoolStatus.ADMIN_WITHDREW &&
            _pools[_poolId].status != PoolStatus.UNSTAKE_BUFFERING &&
            _pools[_poolId].status != PoolStatus.WAIT_ADMIN_RETURNED_FUND
        ) revert ("Can not unstake in active time");// if allow user to unstake when miner has not withdrawed, logic will be break

        // In this function, we only allow user to unstake all.
        uint256 unstakeAmount = _userPoolInfo[_poolId][msg.sender].stakedAmount;

        if (unstakeAmount == 0) revert ("User's staked balance is zero");

        //check msg sender already has unstaked or unstake partial
        if (userWannaUnstakeAmount[_poolId][msg.sender] == unstakeAmount || userWannaUnstakeAmount[_poolId][msg.sender] > 0) revert ("msg sender already have called unstake()");

        _userPoolInfo[_poolId][msg.sender].isStaked = false;
//        stakedUsersOf[_poolId].erase(msg.sender);

        uint256 reqId = unstakedReqId++;
        unstakedReqInfo[reqId] = UnstakedReqInfo(_poolId, msg.sender, unstakeAmount, uint40(block.timestamp));

        stakedUsersOf[_poolId].erase(msg.sender); //remove user from the staked list
        bool isFirstUnstake = false;
        if (_pools[_poolId].status == PoolStatus.INACTIVE) {
            _userPoolInfo[_poolId][msg.sender].stakedAmount = 0;
            userWannaUnstakeAmount[_poolId][msg.sender] = 0;
            _userInfo[msg.sender].reserve1 += unstakeAmount; //total unstaked amount during the life time of contract

            safeTransferNative(msg.sender, unstakeAmount);
        } else if (_pools[_poolId].status == PoolStatus.ADMIN_WITHDREW) {
            userUnstakeReqIds[_poolId][msg.sender].insert(reqId); //queue
            poolUnstakeReqIds[_poolId].insert(reqId); //queue

            userWannaUnstakeAmount[_poolId][msg.sender] += unstakeAmount;

            if (poolUnstakedInfo[_poolId].firstReqTimestamp == 0) {
                isFirstUnstake = true;
                uint40 bufferingTimeExpireAt = uint40(block.timestamp + defaultUnstakeBufferTime);
                poolUnstakedInfo[_poolId] = PoolUnstakedInfo(uint40(block.timestamp), bufferingTimeExpireAt, unstakeAmount);

            } else {
                poolUnstakedInfo[_poolId].totalUnstakedAmount += unstakeAmount;
            }
        }

            //TODO: add event
        emit UserUnstake(msg.sender, _poolId, UserUnstakeEventInfo(unstakeAmount, reqId, _pools[_poolId].status, uint40(block.timestamp), isFirstUnstake));
    }

    //TODO: Kelvin
    function restake(uint32 _poolId) external {
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);


    }

    function resolveUnstake(uint32 _poolId) public {
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);
        if (_pools[_poolId].status != PoolStatus.UNSTAKE_BUFFERING) revert ("Invalid pool status");
        //TODO ccheck timestamp >= buffering timestamp

        // If the stake amounnt from providers is less than the unstake amount.
        // We refund to providers and change status. Now, miner call unregister in workerhub
        if (poolUnstakedInfo[_poolId].totalUnstakedAmount > 0) {
//            _refundToProvider();
            _pools[_poolId].status = PoolStatus.WAIT_ADMIN_RETURNED_FUND;
        } else if (poolUnstakedInfo[_poolId].totalUnstakedAmount == 0) {
            _payoutAndReplaceUnstakers(_poolId);
        }
    }

    function _refundToProvider(uint32 _poolId) internal virtual {

    }

    function _payoutAndReplaceUnstakers(uint32 _poolId) internal virtual {

    }

    //TODO: Kelvin
    function getUnstakeInfo(uint32 _poolId, address _user) public view {

    }

    //TODO: anh Vinkent
    function minerRefundPoolBalance(uint32 _poolId) external payable {
        require(_poolId > 0 && _poolId < _nextPoolId, Errors.INV_POOL_ID);

        address poolMiner = _pools[_poolId].minerAddress;
        uint256 refundValue = _pools[_poolId].amountToActive;
        if (msg.sender != poolMiner) revert ("Msg sender is not the pool miner");
        if (msg.value != refundValue) revert ("Msg value is not enough");

        //TODO: check status, check waiting time expire


    }

    //TODO: anh Vinkent
    function userClaimUnstakedAmount(uint32 poolId) external {

    }

    function setDefaultUnstakeBufferTime(uint40 amountInSecond) external onlyAdmin {
        require(amountInSecond > 0, Errors.INV_ADD);

        defaultUnstakeBufferTime = amountInSecond;
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
