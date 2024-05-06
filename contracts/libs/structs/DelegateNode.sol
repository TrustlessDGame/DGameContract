// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library DelegateNodeStruct {
    enum PoolStatus {
        INACTIVE,
        ACTIVE
    }

    struct PoolInfo {
        string name;
        string image;
        PoolStatus status;
        uint32 id;
        uint256 stakedAmount;
        uint256 amountToActive;
        StakedInfo[] stakedInfos;  // Array of stake info of this pool
        uint32 feePercent; // feePercent / 10_000; 1 <=> 0.01%; reward 100 => fee for protocol = 1 => 99,99 to users
    }

    struct StakedInfo {
        address user;
        uint256 amount;
        uint256 blockNumber;
    }
}
