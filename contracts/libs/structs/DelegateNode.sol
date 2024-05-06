// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library DelegateNodeStruct {
    enum PoolStatus {
        INACTIVE,
        ACTIVE
    }
    struct PoolInfo {
        PoolStatus status;
        uint32 id;
        uint256 stakedAmount;
        uint256 amountToActive;
        mapping(address => uint256) stakedAmounts; // map user address to staked amount
        StakedInfo[] stakedInfos;  // Array of stake info of this pool
    }

    struct StakedInfo {
        address user;
        uint256 amount;
        uint256 blockTime;
    }
}
