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

    // createVault
    error IncorrectCreationNfts();
    error InvalidNfts(uint256[] tokenIds);
    error TotalFeeFactorExceeded();

    // stakeRealmPoints
    error SignatureExpired();
    error MinimumRpRequired();
    error SignatureAlreadyExecuted();
    error InvalidSignature();
    error InvalidSender();
    
    // updateVaultFees
    error UserIsNotCreator();
    error NftFeeCanOnlyBeIncreased();
    error CreatorFeeCanOnlyBeDecreased();

    // _cache
    error NonExistentVault(bytes32 vaultId);

    // updateDistribution
    error InvalidDistributionParameters();
    error NonExistentDistribution();
    error DistributionStarted();
    error DistributionEnded();
    error InvalidDistributionStartTime();
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
    
    // updateNftMultiplier
    error InvalidMultiplier();

    // updateBoostedBalances
    error NoActiveDistributions();

    // endDistributionImmediately
    error DistributionManuallyEnded();

    // freeze
    error IsFrozen();
    error NotFrozen();

    // endTime
}