pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TestUpgradeable is Initializable, OwnableUpgradeable {
    address public _admin;

    function initialize(address admin) initializer public {
        require(admin != address(0x0), "err");
        _admin = admin;

        __Ownable_init();
    }
}
