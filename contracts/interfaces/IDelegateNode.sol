// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDelegateNode {
    enum PoolStatus {
        INACTIVE,
        ACTIVE,
        ADMIN_WITHDREW,
        ADMIN_RETURNED_FUND, // DONT USE this
        UNSTAKE_BUFFERING, // UNSTAKE_BUFFERING can back to ADMIN_WITHDREW or WAIT_ADMIN_RETURNED_FUND
        WAIT_ADMIN_RETURNED_FUND // 21 days, after this 21 days, admin return fund to pool, and pool back to inactive, user claim unstake amount if exist in list unstake
    }

    struct PoolInfo {
        string name;
        string image;
        PoolStatus status;
        uint32 id;
        uint256 stakedAmount; // This is the current balance of pool
        uint256 amountToActive;
        StakedInfo[] stakedInfos;
        uint32 feePercent; // feePercent / 10_000; 0.1 <=> 10%
        address minerAddress;
        address[] stakedUsersSet; // TODO @kelvin update distribute reward DONT USE THIS INFO
    }

    struct UserPoolInfo {
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

    // struct UnStakedInfo {
    //     mapping(uint256 => uint256) caps; // claimed block => amount
    //     uint256[] blocks;   // list keys of caps
    // }

    struct UserInfo {
        uint256 totalReward;
        uint256 totalClaimed;
        uint256 reserve1; //total unstaked amount of user
    }

    struct UnstakedReqInfo {
        uint32 poolId;
        address unstaker;
        uint256 amount;
        uint40 requestTime;
    }

    struct PoolUnstakedInfo {
        uint40 firstReqTimestamp;
        uint40 bufferTimeExpireAt;
        uint256 totalUnstakedAmount; //The total amount that user WANNA unstake
        uint256 reimbursementAmount;
    }

    struct UserUnstakeEventInfo {
        uint256 amount;
        uint256 unstakeId;
        PoolStatus poolStatus;
        uint40 requestTime;
        bool isFirstUnstake;
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
    event DefaultUnstakeBufferTimeUpdate(address indexed caller, uint40 oldTime, uint40 newTime);

    event UserClaimReward(address indexed caller, uint32 indexed poolId, uint256 amount);
    event UserFullClaimReward(address indexed caller, uint32 indexed poolId, uint256 amount);
    event MinerReceiveReward(address indexed miner, uint32 indexed poolId, uint256 amount, uint256 fee);
    event UserReceiveRewardFromMiner(address indexed receiver, uint32 indexed poolId, uint256 amount);
    event UserUnstake(address indexed caller, uint32 indexed poolId, UserUnstakeEventInfo eventInfo);
    event ResolveUnstake(address indexed caller, uint32 indexed poolId, PoolStatus status);
    event UserClaimUnstakedAmount(address indexed caller, uint32 indexed poolId, uint256 claimedAmount);
    event MinerRefundPoolBalance(address indexed miner, uint32 indexed poolId, uint256 refundedValue);
    event UserRestake(address indexed caller, uint32 indexed pooId, uint256 restakedAmount, uint256 remainingUnstakeAmount);
    // errors
    error FailedTransfer();
    error InvalidPoolId();
    error InvalidPoolStatus();
    error InvalidTransferedValue();
    error ZeroAmountToActiveError();
    error NoRewardToClaim();
    error ZeroStakedAmountError();

    error UnstakeBufferExpire();

    error UnstakeAlreadyCalled();
    error PrematureResolveUnstake();
    error PrematureClaimUnstake();
    error ZeroClaimableUnstakedAmount();

    error PrematureMinerRefundPool();
    error SenderNotPoolMiner();
    error RefundedValueNotEnough();

    error PrematureRestake();
}
