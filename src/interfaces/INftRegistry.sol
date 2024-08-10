// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface INftRegistry {

    function recordStake(address onBehalfOf, uint256[] calldata tokenIds, bytes32 vaultId) external;
    function recordUnstake(address onBehalfOf, uint256[] calldata tokenIds, bytes32 vaultId) external;
    
    // mapping
    function nfts(uint256 tokenId) external view returns(address owner, bytes32 vaultId);
}