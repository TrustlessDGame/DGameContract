// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Set} from "../libs/Set.sol";
import {IDelegateNode} from "../interfaces/IDelegateNode.sol";

abstract contract DelegateNodeStorage is IDelegateNode {
    address public _admin;
    address public _poolAdmin;
    uint32 public _nextPoolId;
    uint256 public _defaultAmountToActive; // 25000 EAI
    mapping(uint32 => PoolInfo) public _pools;
    uint32 public _defaultPoolFee; // 1000 => 10% (0.1)
    uint256 public _defaultWaitBlock;
    address public _moderator;
    mapping(uint32 => mapping(address => UserPoolInfo)) public _userPoolInfo;
    mapping(uint32 => Set.AddressSet) internal stakedUsersOf;
    mapping(address => UserInfo) public _userInfo;

    // Unstake
    uint256 public unstakedReqId;
    mapping(uint32 => mapping(address => uint256))
        public userWannaUnstakeAmount;
    mapping(uint32 => mapping(address => Set.Uint256Set))
        internal userUnstakeReqIds;

    mapping(uint32 => Set.Uint256Set) internal poolUnstakeReqIds;
    mapping(uint256 => UnstakedReqInfo) public unstakedReqInfo;

    mapping(uint32 => PoolUnstakedInfo) public poolUnstakedInfo;

    uint40 public defaultUnstakeBufferTime;
    address public workerhubAddress;

    mapping(uint256 => uint40) public unstakeClaimableTime;

    uint256[91] private __gap;
}
