// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

library Errors {
    enum ReturnCode {
        SUCCESS,
        FAILED
    }

    string public constant SUCCESS = "0";

    address public constant ZERO_ADDR = address(0x0);

    // common errors
    string public constant INV_ADD = "100";
    string public constant ONLY_ADMIN_ALLOWED = "101";
    string public constant ONLY_CREATOR = "102";

    // validation error
    string public constant MISSING_NAME = "200";
    string public constant INV_ADD_GAME_CONTRACT = "201";
    string public constant INV_GAME_ID = "202";
    string public constant INV_DECOMPRESS_SCRIPT = "203";
}