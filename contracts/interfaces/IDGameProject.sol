pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "../libs/structs/NFTDGameProject.sol";

interface IDGameProject is IERC721Upgradeable {
    function gameDetail(uint256 _gameId) external view returns (NFTDGameProject.DGameProject memory game);
}
