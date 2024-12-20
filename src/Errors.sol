// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title Errors library
 * @author Calnix
 * @notice Defines the error messages emitted by the different contracts of the Moca protocol
 */

library Errors {

    error Test(uint256 counter);
    
    error InvalidVaultPeriod();
    error InvalidStakingPeriod();
    //error InsufficientTimeLeft();

    error NonExistentVault(bytes32 vaultId);
    error UserIsNotVaultCreator(bytes32 vaultId, address user) ;

    error VaultNotMatured(bytes32 vaultId);
    
    error UserHasNoNftStaked(bytes32 vaultId, address user);
    error UserHasNoTokenStaked(bytes32 vaultId, address user);
    error UserHasNothingStaked(bytes32 vaultId, address user);

    error TotalFeeFactorExceeded();
    error NftFeeCanOnlyBeIncreased(bytes32 vaultId);
    error CreatorFeeCanOnlyBeDecreased(bytes32 vaultId);
    
    error NftStakingLimitExceeded(bytes32 vaultId, uint256 currentNftAmount);


    error InsufficientRealmPoints(uint256 currentRealmPoints, uint256 requiredRealmPoints);

    error VaultHasZeroStakedTokens();
    error VaultHasZeroStakedNfts();

    error IncorrectCreationNfts();
    error IncorrectNftOwner(uint256 tokenId);
    error NftAlreadyStaked(uint256 tokenId);

    error VaultCooldownInitiated();
    error VaultEnded(bytes32 vaultId, uint256 endTime);

    error NoActiveDistributions();

    // updateDistribution
    error DistributionEnded();
    error DistributionStarted();
    error InvalidNewEndTime();

    error VaultHasNotYetEnded();

    
    // stakeRP
    error MinimumRpRequired();
    error InvalidSignature();
    error SignatureExpired();

    // setupDistribution
    error DistributionAlreadySetup();
    error InvalidEndTime();
    //update distribution
    error InvalidStartTime();
    error InvalidDistributionParameters();

}