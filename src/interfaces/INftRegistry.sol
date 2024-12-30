// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface INftRegistry {

    function recordStake(address onBehalfOf, uint256[] calldata tokenIds, bytes32 vaultId) external;
    function recordUnstake(address onBehalfOf, uint256[] calldata tokenIds, bytes32 vaultId) external;
    function recordUnstake(address onBehalfOf, uint256[] calldata tokenIds, bytes32[] calldata vaultIds) external;

    function checkIfUnassignedAndOwned(address user, uint256[] memory tokenIds) external view returns (uint256);
    
    // mapping
    function nfts(uint256 tokenId) external view returns(address owner, bytes32 vaultId);
    
}