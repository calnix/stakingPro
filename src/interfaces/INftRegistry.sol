// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface INftRegistry {

    function checkIfUnassignedAndOwned(address user, uint256[] memory tokenIds) external view;
    function recordStake(address onBehalfOf, uint256[] calldata tokenIds, bytes32 vaultId) external;
    function recordUnstake(address onBehalfOf, uint256[] calldata tokenIds, bytes32 vaultId) external;    
}