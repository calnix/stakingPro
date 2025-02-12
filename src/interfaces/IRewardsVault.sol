// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IRewardsVault {

    // distribution functions
    function setupDistribution(uint256 distributionId, uint32 dstEid, bytes32 tokenAddress, uint256 totalRequired) external;
    function endDistribution(uint256 distributionId, uint256 totalEmitted) external;
    function updateDistribution(uint256 distributionId, uint256 newTotalRequired) external;
    
    // reward functions
    function payRewards(uint256 distributionId, uint256 amount, address to) external payable;

    // deposit/withdraw functions
    function deposit(uint256 distributionId, uint256 amount, address from) external;
    function withdraw(uint256 distributionId, uint256 amount, address to) external;

    // View functions
    function distributions(uint256 distributionId) external view returns(
        uint32 dstEid,
        bytes32 tokenAddress,
        uint256 totalRequired,
        uint256 totalClaimed,
        uint256 totalDeposited,
        uint256 manuallyEnded
    );

    function users(address user) external view returns(address evmAddress, bytes32 solanaAddress);

}