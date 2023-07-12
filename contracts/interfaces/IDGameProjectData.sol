pragma solidity ^0.8.0;

interface IDGameProjectData {
    function gameURI(uint256 projectId) external view returns (string memory result);
    function gameHTML(uint256 projectId) external view returns (string memory result);
}
