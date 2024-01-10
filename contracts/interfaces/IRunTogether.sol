// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "../libs/structs/RunTogetherStruct.sol";

interface IRunTogether is IERC721Upgradeable {
    // Event to log token transfers
    event TokensReceived(address indexed from, uint256 eventId, address tokenAddress, uint256 amount);

    function receiveTokens(uint256 eventId, address tokenAddress, uint256 amount) external;

    function join(uint256 eventId, address participantAddr, RunTogetherObjectStruct.RunTogetherParticipant memory data) external payable;

    function setParticipantData(uint256 eventId, address athlete, string memory data) external;
}
