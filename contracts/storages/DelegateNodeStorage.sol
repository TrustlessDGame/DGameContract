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
    uint256 public _defaultWaitBlock; // DEPRECATE, dont use
    address public _moderator;
    mapping(uint32 => mapping(address => UserPooInfo)) public _userPoolInfo;
    mapping(uint32 => Set.AddressSet) internal stakedUsersOf;
    mapping(address => UserInfo) public _userInfo;

    // Unstake
    uint256 public unstakedReqId; // current unstakeId
    mapping(uint32 => mapping(address => uint256)) public userWannaUnstakeAmount; //poolId => user address => total unstake amount user wanna unstake
    mapping(uint32 => mapping(address => Set.Uint256Set)) userUnstakeReqIds; //poolId => user address => set of unstake reqs that user wanna unstake

    mapping(uint32 => Set.Uint256Set) poolUnstakeReqIds; // pool Id => pending unstake req's id
    mapping(uint256 => UnstakedReqInfo) public unstakedReqInfo; // unstaked Id => UserUnstakedInfo

    mapping(uint32 => PoolUnstakedInfo) poolUnstakedInfo; // pool Id => PoolUnstakedInfo

    uint40 public defaultUnstakeBufferTime; // Only buffer time at DELEGATE NODE contract, dont include waiting time from workerHubContract, Unit: second
    address public workerhubAddress;

    uint256[90] private __gap;
}
