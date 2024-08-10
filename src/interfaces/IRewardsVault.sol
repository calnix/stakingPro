// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRewardsVault {
    // state vars
    function pool() external view returns(address);
    function totalPaidRewards() external view returns(uint256);
    function totalVaultRewards() external view returns(uint256);

    function payRewards(address to, uint256 amount) external;

    // onlyRole(MONEY_MANAGER_ROLE)
    function withdraw(address to, uint256 amount) external;
    function deposit(address from, uint256 amount) external;

    // onlyRole(ADMIN_ROLE)
    function setPool(address newPool) external;
    function recoverERC20(address tokenAddress, address target, uint256 amount) external;
}