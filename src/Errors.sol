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

    error NonExistentVault(uint256 vaultId);
    error UserIsNotVaultCreator(uint256 vaultId, address user) ;

    error VaultNotMatured(uint256 vaultId);
    
    error UserHasNoNftStaked(uint256 vaultId, address user);
    error UserHasNoTokenStaked(uint256 vaultId, address user);
    error UserHasNothingStaked(uint256 vaultId, address user);

    error TotalFeeFactorExceeded();
    error NftFeeCanOnlyBeIncreased(uint256 vaultId);
    error CreatorFeeCanOnlyBeDecreased(uint256 vaultId);
    
    error NftStakingLimitExceeded(uint256 vaultId, uint256 currentNftAmount);


    error InsufficientRealmPoints(uint256 currentRealmPoints, uint256 requiredRealmPoints);

    error VaultHasZeroStakedTokens();
    error VaultHasZeroStakedNfts();

    error IncorrectCreationNfts();
    error IncorrectNftOwner(uint256 tokenId);
    error NftAlreadyStaked(uint256 tokenId);

    error VaultCooldownInitiated();
    error VaultEnded(uint256 vaultId, uint256 endTime);

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