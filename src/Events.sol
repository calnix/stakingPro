// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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
event RPMigrated(address indexed user, bytes32 indexed vaultId, bytes32 indexed newVaultId, uint256 amount);

// unstakeAll
event UnstakedTokens(address indexed user, bytes32 indexed vaultId, uint256 amount);
event UnstakedNfts(address indexed user, bytes32 indexed vaultId, uint256[] tokenIds);

// migrateVaults
event VaultMigrated(
    address indexed user,
    bytes32 indexed oldVaultId,
    bytes32 indexed newVaultId,
    uint256 stakedTokens,
    uint256 stakedRealmPoints,
    uint256[] tokenIds
);

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

// updateMaximumFeeFactor
event MaximumFeeFactorUpdated(uint256 oldFactor, uint256 newFactor);

// updateMinimumRealmPoints
event MinimumRealmPointsUpdated(uint256 oldAmount, uint256 newAmount);

// updateCreationNfts
event CreationNftRequirementUpdated(uint256 oldAmount, uint256 newAmount);

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

// distribution management
event DistributionIndexUpdated(uint256 indexed distributionId, uint256 lastUpdateTimestamp, uint256 oldIndex, uint256 newIndex);
event DistributionCompleted(uint256 indexed distributionId, uint256 endTime, uint256 totalEmitted);

// freeze
event PoolFrozen(uint256 timestamp);

// emergencyExit
event UnstakedTokens(address indexed user, bytes32[] indexed vaultIds, uint256 amount);
event UnstakedNfts(address indexed user, bytes32[] indexed vaultIds, uint256[] tokenIds);
