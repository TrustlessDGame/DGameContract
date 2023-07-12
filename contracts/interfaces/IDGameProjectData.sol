pragma solidity ^0.8.0;

interface IDGameProjectData {
    function gameURI(uint256 projectId) external view returns (string memory result);
    function ethersjsLibScript(string memory fileName, uint256 chunkIndex) external view returns(bytes memory data, int256 nextChunkIndex);
    function tokenHTML(uint256 gameId) external view returns (string memory result);
}
