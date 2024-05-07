// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library DelegateNodeStruct {
    enum PoolStatus {
        INACTIVE,
        ACTIVE,
        ADMIN_WITHDREW
    }

    struct PoolInfo {
        string name;
        string image;
        PoolStatus status;
        uint32 id;
        uint256 stakedAmount;
        uint256 amountToActive;
        StakedInfo[] stakedInfos;
//        mapping(address => UnStakedInfo) mapUnStakedInfos;  // map user => un stake info
        uint32 feePercent; // feePercent / 10_000; 0.1 <=> 10%
        address minerAddress;
    }

    struct StakedInfo {
        address user;
        uint256 amount;
        uint256 blockNumber;
    }

    struct UnStakedInfo {
        mapping(uint256 => uint256)  caps; // claimed block => amount
        uint256[] blocks;   // list keys of caps
    }
}
