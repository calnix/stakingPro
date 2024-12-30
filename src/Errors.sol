// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library Errors {
    // generic (used across multiple functions)
    error InvalidAmount();
    error InvalidVaultId();
    error InvalidAddress();
    error InvalidArray();
    error VaultAlreadyEnded(bytes32 vaultId);

    // createVault
    error IncorrectCreationNfts();
    error InvalidNfts(uint256[] tokenIds);
    error TotalFeeFactorExceeded();

    // stakeRealmPoints
    error SignatureExpired();
    error MinimumRpRequired();
    error SignatureAlreadyExecuted();
    error InvalidSignature();

    // updateVaultFees
    error UserIsNotCreator();
    error NftFeeCanOnlyBeIncreased();
    error CreatorFeeCanOnlyBeDecreased();

    // _cache
    error NonExistentVault(bytes32 vaultId);
    error VaultEnded(bytes32 vaultId, uint256 endTime);

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
    
    // updateBoostedBalances
    error NoActiveDistributions();

    // endDistributionImmediately
    error DistributionOver();
    error DistributionManuallyEnded();

    // freeze
    error IsFrozen();
    error NotFrozen();
}