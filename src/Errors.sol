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
    error InvalidCreationNfts();
    error InvalidNfts();
    error MaximumFeeFactorExceeded();
    error NoActiveDistributions();

    // stakeRealmPoints
    error SignatureExpired();
    error MinimumRpRequired();
    error InvalidSignature();
    error UserHasNothingStaked(bytes32 vaultId, address user);
    
    // claimRewards
    error NoStakedAssets();
    error StakingPowerDistribution();
    error DistributionDoesNotExist();

    // activateCooldown
    error VaultAlreadyRemoved();

    // setRewardsVault
    error ActiveTokenDistributions();

    // updateActiveDistributions
    error InvalidMaxActiveAllowed();

    // updateMaximumFeeFactor   
    error InvalidMaxFeeFactor();

    // updateVaultFees
    error CreatorFeeCanOnlyBeDecreased();
    error NftFeeCanOnlyBeIncreased();
    error RealmPointsFeeCanOnlyBeIncreased();
    error IncorrectFeeComposition();

    // setupDistribution
    error MaxActiveDistributions();
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
    error InvalidNewTotalRequired();
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
    error BalanceRequiredExceeded();
    // payRewards::V2
    error InsufficientGas();
    error PayableBlocked();
    // deposit::V2
    error CallDepositOnRemote();
}