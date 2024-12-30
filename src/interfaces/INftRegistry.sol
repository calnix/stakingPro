// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface INftRegistry {

    function checkIfUnassignedAndOwned(address user, uint256[] memory tokenIds) external view returns (uint256);
    function recordStake(address onBehalfOf, uint256[] calldata tokenIds, bytes32 vaultId) external;
    function recordUnstake(address onBehalfOf, uint256[] calldata tokenIds, bytes32 vaultId) external;

    // note: this is for emergency exit need to implement
    function recordUnstake(address onBehalfOf, uint256[] calldata tokenIds, bytes32[] calldata vaultIds) external;

    
}