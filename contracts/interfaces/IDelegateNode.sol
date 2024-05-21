// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDelegateNode {
    enum PoolStatus {
        INACTIVE,
        ACTIVE,
        ADMIN_WITHDREW,
        ADMIN_RETURNED_FUND
    }

    struct PoolInfo {
        string name;
        string image;
        PoolStatus status;
        uint32 id;
        uint256 stakedAmount;
        uint256 amountToActive;
        StakedInfo[] stakedInfos;
        uint32 feePercent; // feePercent / 10_000; 0.1 <=> 10%
        address minerAddress;
        address[] stakedUsersSet;
    }

    struct UserPooInfo {
        bool isStaked;
        uint256 stakedAmount;
        uint256 rewardAmount;
        uint256 claimedAmount;
    }

    struct StakedInfo {
        address user;
        uint256 amount;
        uint256 blockNumber;
    }

    struct UnStakedInfo {
        mapping(uint256 => uint256) caps; // claimed block => amount
        uint256[] blocks;   // list keys of caps
    }

    struct UserInfo {
        uint256 totalReward;
        uint256 totalClaimed;
        uint256 reserve1;
    }

    // event
    event CreatePool(PoolInfo poolInfo);
    event Stake(address indexed user, uint256 amount, PoolInfo poolInfo);
    event ActivePool(PoolInfo poolInfo);
    event DeActivePool(PoolInfo poolInfo);
    event UnStake(address user, uint256 amount, uint32 poolId, uint256 claimedBlock);
    event ClaimUnStake(address user, uint256 amount, uint32 poolId, uint256 claimedBlock);
    event ReStakeUnStakedPool(address user, uint256 unStakedAmount, uint32 oldPoolId, uint32 newPoolId);
    event AdminWithdrawByPool(address indexed to, uint256 amount, PoolInfo poolInfo);
    event AdminWithdraw(address indexed to, uint256 amount);

    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event ModeratorChanged(address indexed oldModerator, address indexed newModerator);
    event AmountToActiveUpdated(address indexed caller, uint32 indexed poolId, uint256 oldAmount, uint256 newAmount);
    event PoolNameUpdated(uint32 indexed poolId, string oldName, string newName);
    event PoolImageUpdated(uint32 indexed poolId, string oldImage, string newImage);
    event PoolFeePercentUpdated(uint32 indexed poolId, uint32 oldFeePercent, uint32 newFeePercent);
    event MinerAddressUpdated(uint32 indexed poolId, address oldAddress, address newAddress);
    event UserClaimReward(address indexed caller, uint32 indexed poolId, uint256 amount);
    event UserFullClaimReward(address indexed caller, uint32 indexed poolId, uint256 amount);
    event MinerReceiveReward(address indexed miner, uint32 indexed poolId, uint256 amount, uint256 fee);

    // errors
    error FailedTransfer();
    error InvalidPoolId();
    error InvalidTransferedValue();
    error AmountToActiveZeroError();
    error NoRewardToClaim();
}
