// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IRewardsVault {
    // State vars
    function pool() external view returns(address);
    function srcEid() external view returns(uint32);
    
    // Roles
    function ADMIN_ROLE() external view returns(bytes32);
    function MONEY_MANAGER_ROLE() external view returns(bytes32);

    // Core functions
    function setUpDistribution(uint256 distributionId, uint32 dstEid, bytes32 tokenAddress, uint256 totalRequired) external;
    function endDistributionImmediately(uint256 distributionId) external;
    
    function payRewards(uint256 distributionId, uint256 amount, address to) external;

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