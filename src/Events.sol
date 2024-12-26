// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// generic
event PoolFrozen(uint256 timestamp);
event RecoveredTokens(address indexed token, address indexed receiver, uint256 amount);

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
event VaultMultiplierUpdated(bytes32 indexed vaultId, uint256 oldBoostedStakedTokens, uint256 newBoostedStakedTokens);
// stakeRP
event StakedRealmPoints(address indexed user, bytes32 indexed vaultId, uint256 amount, uint256 boostedAmount);

// unstakeAll
event UnstakedTokens(address indexed user, bytes32 indexed vaultId, uint256 amount);
event UnstakedNfts(address indexed user, bytes32 indexed vaultId, uint256[] tokenIds);

// claimRewards
event RewardsClaimed(bytes32 indexed vaultId, address indexed user, uint256 amount);

// updateFees
event CreatorFeeFactorUpdated(bytes32 indexed vaultId, uint256 oldFactor, uint256 newFactor);
event NftFeeFactorUpdated(bytes32 indexed vaultId, uint256 oldFactor, uint256 newFactor);
event RealmPointsFeeFactorUpdated(bytes32 indexed vaultId, uint256 oldFactor, uint256 newFactor);

// vault management
event VaultRemoved(bytes32 indexed vaultId);
event VaultsRemoved(bytes32[] vaultIds, uint256 vaultsNotEnded);

event VaultCooldownInitiated(bytes32 indexed vaultId);

// migrateVaults
event VaultMigrated(
    address indexed user,
    bytes32 indexed oldVaultId,
    bytes32 indexed newVaultId,
    uint256 stakedTokens,
    uint256 stakedRealmPoints,
    uint256 numOfNfts
);

// distribution management
event DistributionCreated(uint256 indexed distributionId, uint256 startTime, uint256 endTime, uint256 emissionPerSecond, uint256 tokenPrecision);
event DistributionUpdated(uint256 indexed distributionId, uint256 startTime, uint256 endTime, uint256 emissionPerSecond);
event DistributionIndexUpdated(
    uint256 indexed distributionId,
    uint256 lastUpdateTimestamp,
    uint256 oldIndex,
    uint256 newIndex
);
event DistributionCompleted(
    uint256 indexed distributionId,
    uint256 endTime,
    uint256 totalEmitted
);

// admin configuration
event RewardsVaultSet(address indexed oldVault, address indexed newVault);
event CreationNftRequirementUpdated(uint256 oldAmount, uint256 newAmount);
event MinimumRealmPointsUpdated(uint256 oldAmount, uint256 newAmount);
event VaultCooldownDurationUpdated(uint256 oldDuration, uint256 newDuration);

// updateNftMultiplier
event NftMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);

// updateBoostedBalances
event BoostedBalancesUpdated(bytes32[] vaultIds);
