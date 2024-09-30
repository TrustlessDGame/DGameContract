// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.12;
import "contracts/interfaces/IWorkerHub.sol";

contract MockWorkerHub is IWorkerHub {
    uint40 public delayTime = 0;

    constructor(uint40 _delayTime) {
        delayTime = _delayTime;
    }

    function updateDelayTime(uint40 _delayTime) external {
        delayTime = _delayTime;
    }

    function unstakeDelayTime() view external returns(uint40) {
        return delayTime;
    }
}
