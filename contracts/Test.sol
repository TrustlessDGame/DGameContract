pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Test is Ownable {
    address public _admin;
    constructor(
        address admin
    ) {
        require(admin != address(0x0), "err");
        _admin = admin;
    }
}
