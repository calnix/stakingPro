// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// generic (used across multiple functions)
error InvalidVaultId();
error InvalidAmount();
error InvalidAddress();
error InvalidArray();
error VaultAlreadyEnded(bytes32 vaultId);

// _cache
error NonExistentVault(bytes32 vaultId);
error VaultEnded(bytes32 vaultId, uint256 endTime);

// createVault
error IncorrectCreationNfts();
error IncorrectNftOwner(uint256 tokenId);
error NftAlreadyStaked(uint256 tokenId);
error TotalFeeFactorExceeded();

// updateDistribution
error InvalidDistributionParameters();
error NonExistentDistribution();
error DistributionAlreadyEnded();
error DistributionStarted();
error InvalidStartTime();
error InvalidEndTime();
error InvalidDistributionEndTime();

// setupDistribution
error ZeroEmissionRate();
error ZeroTokenPrecision();
error DistributionAlreadySetup();
error InvalidDstEid();
error InvalidTokenAddress();

// claimRewards
error StakingPowerDistribution();

// unstakeAll
error UserHasNothingStaked(bytes32 vaultId, address user);

// updateVaultFees
error UserIsNotVaultCreator(bytes32 vaultId, address user);
error NftFeeCanOnlyBeIncreased(bytes32 vaultId);
error CreatorFeeCanOnlyBeDecreased(bytes32 vaultId);

// stakeRealmPoints
error MinimumRpRequired();
error SignatureExpired();
error InvalidSignature();
error InsufficientRealmPoints(uint256 currentRealmPoints, uint256 requiredRealmPoints);

// cooldown
error VaultCooldownNotActivated(bytes32 vaultId);
 
// updateBoostedBalances
error NoActiveDistributions();

// endDistributionImmediately
error DistributionOver();
error DistributionManuallyEnded();

// freeze
error IsFrozen();
error NotFrozen();