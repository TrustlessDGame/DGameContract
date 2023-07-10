pragma solidity ^0.8.0;

interface IDGameData {
    function gameURI(uint256 projectId) external view returns (string memory result);
}
