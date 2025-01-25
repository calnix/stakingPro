// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library Errors {

    // generic (used across multiple functions)
    error NotStarted();
    error StakingEnded();
    error InvalidArray();
    error InvalidAmount();
    error InvalidEndTime();
    error InvalidVaultId();
    error InvalidAddress();
    error InvalidStartTime();
    error UserIsNotCreator();
    error VaultEndTimeSet(bytes32 vaultId);
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
    error UserHasNothingStaked(bytes32 vaultId, address user);
    
    // claimRewards
    error StakingPowerDistribution();

    // updateMaximumFeeFactor   
    error InvalidMaxFeeFactor();

    // updateVaultFees
    error CreatorFeeCanOnlyBeDecreased();
    error NftFeeCanOnlyBeIncreased();
    error RealmPointsFeeCanOnlyBeIncreased();
    error IncorrectFeeComposition();

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
    error InvalidEmissionPerSecond();
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

// -------------------------------------- RewardsVault --------------------------------------------------------------------
    
    error InvalidDistributionId();
    error InsufficientDeposits();
    error DistributionNotSetup();
    error ExcessiveDeposit();
    
    // payRewards::V2
    error InsufficientGas();
    // deposit::V2
    error CallDepositOnRemote();

}