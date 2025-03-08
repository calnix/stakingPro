// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// note: remove
event test(string message, uint256 amount);

// createVault
event VaultCreated(
    bytes32 indexed vaultId,
    address indexed creator,
    uint256 creatorFeeFactor,
    uint256 nftFeeFactor,
    uint256 realmPointsFeeFactor
);

// stakeTokens
event StakedTokens(address indexed user, bytes32 indexed vaultId, uint256 amount);

// stakeNfts
event StakedNfts(address indexed user, bytes32 indexed vaultId, uint256[] tokenIds);
event VaultBoostFactorUpdated(bytes32 indexed vaultId, uint256 oldBoostFactor, uint256 newBoostFactor);

// stakeRP
event StakedRealmPoints(address indexed user, bytes32 indexed vaultId, uint256 amount, uint256 boostedAmount);

// migrateRP
event RealmPointsMigrated(address indexed user, bytes32 indexed vaultId, bytes32 indexed newVaultId, uint256 amount);

// unstakeAll
event UnstakedTokens(address indexed user, bytes32 indexed vaultId, uint256 amount, uint256 boostedAmount);
event UnstakedNfts(address indexed user, bytes32 indexed vaultId, uint256[] tokenIds, uint256 deltaVaultBoostedStakedTokens, uint256 deltaVaultBoostedRealmPoints);

// claimRewards
event RewardsClaimed(bytes32 indexed vaultId, address indexed user, uint256 amount);

// updateFees
event CreatorFeeFactorUpdated(bytes32 indexed vaultId, uint256 oldFactor, uint256 newFactor);
event NftFeeFactorUpdated(bytes32 indexed vaultId, uint256 oldFactor, uint256 newFactor);
event RealmPointsFeeFactorUpdated(bytes32 indexed vaultId, uint256 oldFactor, uint256 newFactor);

// activateCooldown
event VaultCooldownActivated(bytes32 indexed vaultId, uint256 vaultEndTime);
event VaultEnded(bytes32 indexed vaultId);

// endVaults
event VaultsEnded(bytes32[] vaultIds, uint256 vaultsNotEnded);

// stakeOnBehalfOf
event StakedOnBehalfOf(address[] users, bytes32[] vaultIds, uint256[] amounts);

// setEndTime
event StakingEndTimeSet(uint256 endTime);

// setRewardsVault
event RewardsVaultSet(address indexed oldVault, address indexed newVault);

// updateActiveDistributions
event MaximumActiveDistributionsUpdated(uint256 newMaxActiveAllowed);

// updateMaximumFeeFactor
event MaximumFeeFactorUpdated(uint256 oldFactor, uint256 newFactor);

// updateMinimumRealmPoints
event MinimumRealmPointsUpdated(uint256 oldAmount, uint256 newAmount);

// updateCreationNfts
event CreationNftRequiredUpdated(uint256 oldAmount, uint256 newAmount);

// updateVaultCooldown
event VaultCooldownDurationUpdated(uint256 oldDuration, uint256 newDuration);

// setupDistribution
event DistributionCreated(uint256 indexed distributionId, uint256 startTime, uint256 endTime, uint256 emissionPerSecond, uint256 tokenPrecision);
// updateDistribution
event DistributionUpdated(uint256 indexed distributionId, uint256 startTime, uint256 endTime, uint256 emissionPerSecond);
// endDistributionImmediately
event DistributionEnded(uint256 indexed distributionId, uint256 endTime, uint256 totalEmitted);

// enableMaintenance
event MaintenanceEnabled(uint256 timestamp);
// disableMaintenance
event MaintenanceDisabled(uint256 timestamp);
// updateDistributions
event DistributionsUpdated(uint256[] distributionIds);
// updateAllVaultAccounts
event VaultAccountsUpdated(bytes32[] vaultIds);
// updateNftMultiplier
event NftMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
// updateBoostedBalances
event BoostedBalancesUpdated(bytes32[] vaultIds);

// freeze
event PoolFrozen(uint256 timestamp);

// emergencyExit
event TokensExited(address indexed user, bytes32[] indexed vaultIds, uint256 stakedTokens);
event NftsExited(address indexed user, bytes32 indexed vaultIds, uint256[] tokenIds);

//  --------------------------------------  PoolLogic --------------------------------------------------------------------

// _updateUserAccount
event UserAccountUpdated(address indexed user, bytes32 indexed vaultId, uint256 indexed distributionId, uint256 accruedStakingRewards, uint256 accNftStakingRewards, uint256 accRealmPointsRewards);

// _updateVaultAccount
event VaultAccountUpdated(bytes32 indexed vaultId, uint256 indexed distributionId, uint256 totalAccRewards, uint256 accCreatorFee, uint256 accTotalNftFee, uint256 accRealmPointsFee);

// _updateDistribution
event DistributionIndexUpdated(uint256 indexed distributionId, uint256 lastUpdateTimestamp, uint256 oldIndex, uint256 newIndex);
event DistributionCompleted(uint256 indexed distributionId, uint256 endTime, uint256 totalEmitted);


// -------------------------------------- RewardsVault --------------------------------------------------------------------
event ReceiverSet(address indexed setter, address indexed evmAddress, bytes32 indexed solanaAddress);
event DistributionCreated(uint256 indexed distributionId, uint32 dstEid, bytes32 tokenAddress);
event DistributionUpdated(uint256 indexed distributionId, uint256 newTotalRequired);
event DistributionEnded(uint256 indexed distributionId, uint256 finalTotalRequired);
event PayRewards(uint256 indexed distributionId, address indexed to, bytes32 indexed receiver, uint256 amount);
event Deposit(uint256 indexed distributionId, uint32 dstEid, address indexed from, uint256 amount);
event Withdraw(uint256 indexed distributionId, uint32 dstEid, address indexed to, uint256 amount);
