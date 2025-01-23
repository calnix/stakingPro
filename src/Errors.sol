// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library Errors {

    // generic (used across multiple functions)
    error NotStarted();
    error StakingEnded();
    error InvalidAmount();
    error InvalidVaultId();
    error InvalidAddress();
    error InvalidArray();
    error VaultEndTimeSet(bytes32 vaultId);
    error InvalidStartTime();
    error InvalidEndTime();
    error UserIsNotCreator();
    error NonExistentVault(bytes32 vaultId);

    // createVault
    error IncorrectCreationNfts();
    error InvalidNfts();
    error MaximumFeeFactorExceeded();

    // stakeRealmPoints
    error SignatureExpired();
    error MinimumRpRequired();
    error SignatureAlreadyExecuted();
    error InvalidSignature();
    
    // claimRewards
    error StakingPowerDistribution();

    // migrate vaults
    error UserHasNothingStaked(bytes32 vaultId, address user);

    // updateVaultFees
    error CreatorFeeCanOnlyBeDecreased();

    // setupDistribution
    error ZeroTokenPrecision();
    error ZeroEmissionRate();
    error InvalidDistributionStartTime();
    error InvalidDistributionEndTime();
    error InvalidDstEid();
    error InvalidTokenAddress();
    error DistributionAlreadySetup();
    // updateDistribution
    error InvalidDistributionParameters();
    error NonExistentDistribution();
    error DistributionStarted();
    error DistributionEnded();
    // endDistributionImmediately
    error DistributionManuallyEnded();

    // updateNftMultiplier
    error InvalidMultiplier();

    // freeze
    error IsFrozen();
    error NotFrozen();

    // Operator+Maintenance
    error NotInMaintenance();
    error InMaintenance();
}