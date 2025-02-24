// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import './Events.sol';
import {Errors} from './Errors.sol';
import {DataTypes} from './DataTypes.sol';
import {INftRegistry} from "./interfaces/INftRegistry.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {console} from "forge-std/console.sol";

library PoolLogic {
    using SafeERC20 for IERC20;

    function executeStakeTokens(
        uint256[] storage activeDistributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,

        DataTypes.UpdateAccountsIndexesParams memory params,
        uint256 amount
    ) external returns (uint256) {

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(params.vaultId, params.user, vaults, users);
        
        // vault cooldown activated: cannot stake
        if(vault.endTime > 0) revert Errors.VaultEndTimeSet(params.vaultId);

        // storage update: vault and user accounting across all active reward distributions
        _updateUserAccounts(activeDistributions, distributions, vaultAccounts, userAccounts, vault, userVaultAssets, params);

        // calc. boostedStakedTokens
        uint256 incomingBoostedTokens = (amount * vault.totalBoostFactor) / params.PRECISION_BASE;
        
        // increment: vault
        vault.stakedTokens += amount;
        vault.boostedStakedTokens += incomingBoostedTokens;

        // increment: userVaultAssets
        userVaultAssets.stakedTokens += amount;

        // update storage: mappings 
        vaults[params.vaultId] = vault;
        users[params.user][params.vaultId] = userVaultAssets;        

        return incomingBoostedTokens;
    }

    function executeStakeNfts(
        uint256[] storage activeDistributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,

        DataTypes.UpdateAccountsIndexesParams memory params,
        uint256[] calldata tokenIds,
        uint256 incomingNfts,
        uint256 nftMultiplier
    ) external returns (uint256, uint256) {

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(params.vaultId, params.user, vaults, users);
        
        // vault cooldown activated: cannot stake
        if(vault.endTime > 0) revert Errors.VaultEndTimeSet(params.vaultId);

        // storage update: vault and user accounting across all active reward distributions
        _updateUserAccounts(activeDistributions, distributions, vaultAccounts, userAccounts, vault, userVaultAssets, params);
        
        // increment: vault's nfts 
        vault.stakedNfts += incomingNfts;

        // cache
        uint256 oldBoostFactor = vault.totalBoostFactor;
        uint256 oldBoostedRealmPoints = vault.boostedRealmPoints;
        uint256 oldBoostedStakedTokens = vault.boostedStakedTokens;

        // increment: total boost factor
        vault.totalBoostFactor += (incomingNfts * nftMultiplier); 
        emit VaultBoostFactorUpdated(params.vaultId, oldBoostFactor, vault.totalBoostFactor);

        // recalc. boosted balances with new boost factor 
        if (vault.stakedTokens > 0) vault.boostedStakedTokens = (vault.stakedTokens * vault.totalBoostFactor) / params.PRECISION_BASE;            
        if (vault.stakedRealmPoints > 0) vault.boostedRealmPoints = (vault.stakedRealmPoints * vault.totalBoostFactor) / params.PRECISION_BASE;

        // update: user's tokenIds + boostedBalances
        userVaultAssets.tokenIds = _concatArrays(userVaultAssets.tokenIds, tokenIds);

        // update storage: mappings 
        vaults[params.vaultId] = vault;
        users[params.user][params.vaultId] = userVaultAssets;

        return ((vault.boostedStakedTokens - oldBoostedStakedTokens), (vault.boostedRealmPoints - oldBoostedRealmPoints));
    }

    function executeStakeRP(
        uint256[] storage activeDistributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,

        DataTypes.UpdateAccountsIndexesParams memory params,
        uint256 amount
    ) external returns (uint256) {

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(params.vaultId, params.user, vaults, users);
        
        // vault cooldown activated: cannot stake
        if(vault.endTime > 0) revert Errors.VaultEndTimeSet(params.vaultId);

        // storage update: vault and user accounting across all active reward distributions
        _updateUserAccounts(activeDistributions, distributions, vaultAccounts, userAccounts, vault, userVaultAssets, params);

        // calc. boostedStakedRealmPoints
        uint256 incomingBoostedRealmPoints = (amount * vault.totalBoostFactor) / params.PRECISION_BASE;

        // increment: vault
        vault.stakedRealmPoints += amount;
        vault.boostedRealmPoints += incomingBoostedRealmPoints;

        //increment: userVaultAssets
        userVaultAssets.stakedRealmPoints += amount;

        // update storage: mappings 
        vaults[params.vaultId] = vault;
        users[params.user][params.vaultId] = userVaultAssets;

        return incomingBoostedRealmPoints;
    }

    function executeUnstake(
        uint256[] storage activeDistributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,

        DataTypes.UpdateAccountsIndexesParams calldata params,
        uint256 NFT_MULTIPLIER,
        uint256 amount,
        uint256[] calldata tokenIds
    ) external returns (uint256, uint256, uint256) {
        
        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(params.vaultId, params.user, vaults, users);

        // input check: does the user have sufficient assets for unstaking?
        if(userVaultAssets.stakedTokens < amount) revert Errors.InvalidAmount();
        uint256 numOfNftsToUnstake = tokenIds.length;
        if(userVaultAssets.tokenIds.length < numOfNftsToUnstake) revert Errors.InvalidAmount();

        // storage update: vault and user accounting across all active reward distributions
        _updateUserAccounts(activeDistributions, distributions, vaultAccounts, userAccounts, vault, userVaultAssets, params);

        // reverts if tokenIds are not found in userVaultAssets.tokenIds
        // also serves to check that the user owns the inputted nfts
        userVaultAssets.tokenIds = _removeFromArray(userVaultAssets.tokenIds, tokenIds);

        uint256 amountBoosted; 
        uint256 deltaVaultBoostedRealmPoints;
        uint256 deltaVaultBoostedStakedTokens;

        // update tokens
        if(amount > 0){

            // calc. boosted values
            amountBoosted = (amount * vault.totalBoostFactor) / params.PRECISION_BASE;

            // update vault
            vault.stakedTokens -= amount;
            vault.boostedStakedTokens -= amountBoosted;

            // update user
            userVaultAssets.stakedTokens -= amount;
        
            emit UnstakedTokens(params.user, params.vaultId, amount, amountBoosted);             
        }

        // update nfts
        if(numOfNftsToUnstake > 0){
            
            // calc. deltas for vault
            uint256 deltaBoostFactor = numOfNftsToUnstake * NFT_MULTIPLIER;
            deltaVaultBoostedRealmPoints = (deltaBoostFactor * vault.stakedRealmPoints) / params.PRECISION_BASE;
            deltaVaultBoostedStakedTokens += (deltaBoostFactor * vault.stakedTokens) / params.PRECISION_BASE;
            
            // update vault
            vault.stakedNfts -= numOfNftsToUnstake;            
            vault.totalBoostFactor -= deltaBoostFactor;

            // recalc vault's boosted balances, based on remaining staked assets
            if (vault.stakedTokens > 0) vault.boostedStakedTokens -= deltaVaultBoostedStakedTokens;            
            if (vault.stakedRealmPoints > 0) vault.boostedRealmPoints -= deltaVaultBoostedRealmPoints;

            emit UnstakedNfts(params.user, params.vaultId, tokenIds, deltaVaultBoostedStakedTokens, deltaVaultBoostedRealmPoints);             
        }

        // update storage: mappings 
        vaults[params.vaultId] = vault;
        users[params.user][params.vaultId] = userVaultAssets;

        return (amountBoosted, deltaVaultBoostedRealmPoints, deltaVaultBoostedStakedTokens);
    } 

    function executeMigrateRealmPoints(
        uint256[] storage activeDistributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,

        DataTypes.UpdateAccountsIndexesParams memory oldVaultParams,
        DataTypes.UpdateAccountsIndexesParams memory newVaultParams,
        uint256 amount
    ) external returns (uint256, uint256) {

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userOldVaultAssets, DataTypes.Vault memory oldVault) = _cache(oldVaultParams.vaultId, oldVaultParams.user, vaults, users);
        (DataTypes.User memory userNewVaultAssets, DataTypes.Vault memory newVault) = _cache(newVaultParams.vaultId, newVaultParams.user, vaults, users);

        // vault cooldown activated: cannot migrate
        if(newVault.endTime > 0) revert Errors.VaultEndTimeSet(newVaultParams.vaultId);

        // sanity check: user must have sufficient RP in old vault
        if(userOldVaultAssets.stakedRealmPoints < amount) revert Errors.UserHasNothingStaked(oldVaultParams.vaultId, oldVaultParams.user);

        // storage update: vault and user accounting across all active reward distributions
        _updateUserAccounts(activeDistributions, distributions, vaultAccounts, userAccounts, oldVault, userOldVaultAssets, oldVaultParams);
        // storage update: vault and user accounting across all active reward distributions
        _updateUserAccounts(activeDistributions, distributions, vaultAccounts, userAccounts, newVault, userNewVaultAssets, newVaultParams);

        // ---------------------------- update vaults ----------------------------------------------

        // decrement oldVault
        uint256 oldBoostedRealmPoints = (amount * oldVault.totalBoostFactor) / oldVaultParams.PRECISION_BASE; 
        oldVault.stakedRealmPoints -= amount;
        oldVault.boostedRealmPoints -= oldBoostedRealmPoints;
        // decrement oldUserVaultAssets
        userOldVaultAssets.stakedRealmPoints -= amount;
        
        // increment new vault
        uint256 newBoostedRealmPoints = (amount * newVault.totalBoostFactor) / newVaultParams.PRECISION_BASE; 
        newVault.stakedRealmPoints += amount;
        newVault.boostedRealmPoints += newBoostedRealmPoints;
        // increment newUserVaultAssets
        userNewVaultAssets.stakedRealmPoints += amount;

        // EMIT 
        emit RealmPointsMigrated(oldVaultParams.user, oldVaultParams.vaultId, newVaultParams.vaultId, amount);

        // Update storage for both vaults
        vaults[oldVaultParams.vaultId] = oldVault;
        vaults[newVaultParams.vaultId] = newVault;

        // Update storage for both user-vault assets
        users[oldVaultParams.user][oldVaultParams.vaultId] = userOldVaultAssets;
        users[newVaultParams.user][newVaultParams.vaultId] = userNewVaultAssets;

        // global delta
        uint256 totalBoostedDelta;
        if(newBoostedRealmPoints > oldBoostedRealmPoints) {
            
            totalBoostedDelta = (newBoostedRealmPoints - oldBoostedRealmPoints);    
            //1: flag for incrementation
            return(totalBoostedDelta, 1);

        } else{

            totalBoostedDelta = (oldBoostedRealmPoints - newBoostedRealmPoints);
            //0: flag for decrementation
            return(totalBoostedDelta, 0);
        }
    }

    function executeClaimRewards(        
        uint256[] storage activeDistributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,

        DataTypes.UpdateAccountsIndexesParams memory params,
        uint256 distributionId
    ) external returns (uint256) {
        
        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(params.vaultId, params.user, vaults, users);

        // get corresponding user+vault account for this distribution 
        DataTypes.Distribution memory distribution = distributions[distributionId];
        
        // ensure distribution exists
        if(distribution.startTime == 0) revert Errors.DistributionDoesNotExist();
        
        DataTypes.VaultAccount memory vaultAccount = vaultAccounts[params.vaultId][distributionId];
        DataTypes.UserAccount memory userAccount = userAccounts[params.user][params.vaultId][distributionId];

        // only update specified distribution, and its accounts
        (userAccount, vaultAccount, distribution) 
            = _updateUserAccount(activeDistributions, userVaultAssets, userAccount, vault, vaultAccount, distribution, params);
      
        //----------------------- calc. and update vault and user accounts ------------------------

        // expressed in 1E18 precision
        uint256 totalUnclaimedRewards;
        
        // staking MOCA rewards |  accStakingRewards expressed in 1E18 precision
        if (userAccount.accStakingRewards > userAccount.claimedStakingRewards) {

            uint256 unclaimedRewards = userAccount.accStakingRewards - userAccount.claimedStakingRewards;

            userAccount.claimedStakingRewards += unclaimedRewards;
            vaultAccount.totalClaimedRewards += unclaimedRewards;

            totalUnclaimedRewards += unclaimedRewards;
        }

        // staking RP rewards |  accRealmPointsRewards expressed in 1E18 precision
        if (userAccount.accRealmPointsRewards > userAccount.claimedRealmPointsRewards) {

            uint256 unclaimedRpRewards = userAccount.accRealmPointsRewards - userAccount.claimedRealmPointsRewards;

            userAccount.claimedRealmPointsRewards += unclaimedRpRewards;
            vaultAccount.totalClaimedRewards += unclaimedRpRewards;

            totalUnclaimedRewards += unclaimedRpRewards;
        }

        // staking NFT rewards |  accNftStakingRewards expressed in 1E18 precision
        if (userAccount.accNftStakingRewards > userAccount.claimedNftRewards) {

            uint256 unclaimedNftRewards = userAccount.accNftStakingRewards - userAccount.claimedNftRewards;

            userAccount.claimedNftRewards += unclaimedNftRewards;
            vaultAccount.totalClaimedRewards += unclaimedNftRewards;

            totalUnclaimedRewards += unclaimedNftRewards;
        }

        // creator rewards 
        if (vault.creator == params.user) {
            // expressed in 1E18 precision
            uint256 unclaimedCreatorRewards = vaultAccount.accCreatorRewards - userAccount.claimedCreatorRewards;

            if(unclaimedCreatorRewards > 0) {
            
                userAccount.claimedCreatorRewards += unclaimedCreatorRewards;
                vaultAccount.totalClaimedRewards += unclaimedCreatorRewards;
            
                totalUnclaimedRewards += unclaimedCreatorRewards;
            }
        }

        // --------------------------------------------------------------------------------------

        // update storage: accounts and distributions
        distributions[distributionId] = distribution;     
        vaultAccounts[params.vaultId][distributionId] = vaultAccount;  
        userAccounts[params.user][params.vaultId][distributionId] = userAccount;

        // rebase totalUnclaimedRewards to native precision
        uint256 totalUnclaimedRewardsInNative = totalUnclaimedRewards * distribution.TOKEN_PRECISION / 1E18;
        emit RewardsClaimed(params.vaultId, params.user, totalUnclaimedRewardsInNative);

        return totalUnclaimedRewardsInNative;
    }

    function executeUpdateVaultFees(
        uint256[] storage activeDistributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,
        
        DataTypes.UpdateAccountsIndexesParams memory params,
        uint256 nftFeeFactor,
        uint256 creatorFeeFactor,
        uint256 realmPointsFeeFactor
    ) external {

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(params.vaultId, params.user, vaults, users);
        
        // vault cooldown activated: cannot update fees
        if(vault.endTime > 0) revert Errors.VaultEndTimeSet(params.vaultId);

        // sanity check: user must be creator 
        if(vault.creator != params.user) revert Errors.UserIsNotCreator();

        // sanity check: incoming creatorFeeFactor must be lower than current
        if(creatorFeeFactor > vault.creatorFeeFactor) revert Errors.CreatorFeeCanOnlyBeDecreased();
        // sanity check: nftFeeFactor + realmPointsFeeFactor cannot be decreased
        if(nftFeeFactor < vault.nftFeeFactor) revert Errors.NftFeeCanOnlyBeIncreased();
        if(realmPointsFeeFactor < vault.realmPointsFeeFactor) revert Errors.RealmPointsFeeCanOnlyBeIncreased();

        // calculate deltas for each fee factor
        uint256 deltaCreatorFeeFactor = vault.creatorFeeFactor - creatorFeeFactor;
        uint256 deltaNftFeeFactor = nftFeeFactor - vault.nftFeeFactor;
        uint256 deltaRealmPointsFeeFactor = realmPointsFeeFactor - vault.realmPointsFeeFactor;

        // creator can only increase other fees, by the portion he is reducing creator fees
        if(deltaCreatorFeeFactor < deltaNftFeeFactor + deltaRealmPointsFeeFactor) revert Errors.IncorrectFeeComposition();
        
        // storage update: vault and user accounting across all active reward distributions
        _updateUserAccounts(activeDistributions, distributions, vaultAccounts, userAccounts, vault, userVaultAssets, params);

        // emit events for fee changes
        emit CreatorFeeFactorUpdated(params.vaultId, vault.creatorFeeFactor, creatorFeeFactor);    
        emit NftFeeFactorUpdated(params.vaultId, vault.nftFeeFactor, nftFeeFactor);
        emit RealmPointsFeeFactorUpdated(params.vaultId, vault.realmPointsFeeFactor, realmPointsFeeFactor);

        // update fees
        vault.nftFeeFactor = nftFeeFactor;
        vault.creatorFeeFactor = creatorFeeFactor;
        vault.realmPointsFeeFactor = realmPointsFeeFactor;
        
        // update storage 
        vaults[params.vaultId] = vault;
    }

    function executeActivateCooldown(
        uint256[] storage activeDistributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,

        DataTypes.UpdateAccountsIndexesParams memory params
    ) external returns (DataTypes.Vault memory) {

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(params.vaultId, params.user, vaults, users);
        
        // vault cooldown activated: cannot stake
        if(vault.endTime > 0) revert Errors.VaultEndTimeSet(params.vaultId);

        // only creator can activate cooldown
        if(vault.creator != params.user) revert Errors.UserIsNotCreator();

        // storage update: vault and user accounting across all active reward distributions
        _updateUserAccounts(activeDistributions, distributions, vaultAccounts, userAccounts, vault, userVaultAssets, params);

        return vault;
    }

    function executeEndVaults(
        uint256[] storage activeDistributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,

        DataTypes.UpdateAccountsIndexesParams memory params,
        bytes32[] calldata vaultIds,
        uint256 numOfVaults,
        INftRegistry NFT_REGISTRY
    ) external returns (uint256, uint256, uint256, uint256, uint256) {

        // Track total assets to remove from global state
        uint256 totalNftsToRemove;
        uint256 totalTokensToRemove; 
        uint256 totalRealmPointsToRemove;
        uint256 totalBoostedTokensToRemove;
        uint256 totalBoostedRealmPointsToRemove;
            
        uint256 vaultsEnded;

        // cache active distributions to avoid incorrect processing of distributions due to .pop() [in _updateDistributionIndex]
        uint256 numOfDistributions = activeDistributions.length;
        uint256[] memory distributionsToProcess = new uint256[](numOfDistributions);
        for(uint256 i; i < numOfDistributions; ++i) {
            distributionsToProcess[i] = activeDistributions[i];
        }

        // For each distribution [always > 0 due to staking power]
        for(uint256 i; i < numOfDistributions; ++i) {
            
            uint256 distributionId = distributionsToProcess[i];
            DataTypes.Distribution memory distribution = distributions[distributionId];

            // Update distribution first
            distribution = _updateDistributionIndex(distribution, activeDistributions, params.totalBoostedRealmPoints, params.totalBoostedStakedTokens, params.isPaused);
            distributions[distributionId] = distribution;
            
            // Then update all vault accounts for this distribution
            for(uint256 j; j < numOfVaults; ++j) {
                
                // get vault 
                bytes32 vaultId = vaultIds[j];
                DataTypes.Vault memory vault = vaults[vaultId];

                // vault does not exist: skip
                if(vault.creator == address(0)) continue;
                // cooldown NOT activated; cannot end vault: skip
                if(vault.endTime == 0) continue;
                // vault has been removed from circulation: skip
                if(vault.removed == 1) continue;

                // vault account: get and update 
                DataTypes.VaultAccount memory vaultAccount = vaultAccounts[vaultId][distributionId];
                (vaultAccount, ) = _updateVaultAccount(vault, vaultAccount, distribution, activeDistributions, params);
                vaultAccounts[vaultId][distributionId] = vaultAccount;

                // Track assets to remove (only need to do this once per vault)
                if(i == 0) {
                    totalNftsToRemove += vault.stakedNfts;
                    totalTokensToRemove += vault.stakedTokens;
                    totalRealmPointsToRemove += vault.stakedRealmPoints;
                    totalBoostedTokensToRemove += vault.boostedStakedTokens;
                    totalBoostedRealmPointsToRemove += vault.boostedRealmPoints;

                    // return creator NFTs
                    NFT_REGISTRY.recordUnstake(vault.creator, vault.creationTokenIds, vaultId);
                    delete vaults[vaultId].creationTokenIds;

                    // Mark vault as removed
                    vaults[vaultId].removed = 1;
                    ++vaultsEnded;
                }
            }
        }
        
        // num. of vaults skipped 
        uint256 vaultsSkipped = numOfVaults - vaultsEnded; 
        emit VaultsEnded(vaultIds, vaultsSkipped);

        return (totalNftsToRemove, totalTokensToRemove, totalRealmPointsToRemove, totalBoostedTokensToRemove, totalBoostedRealmPointsToRemove);
    }

    function executeStakeOnBehalfOf(
        uint256[] storage activeDistributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,

        DataTypes.UpdateAccountsIndexesParams memory params,
        bytes32[] calldata vaultIds,
        address[] calldata onBehalfOfs,
        uint256[] calldata amounts
    ) external returns (uint256, uint256) {

        uint256 length = amounts.length;
        if(length == 0) revert Errors.InvalidArray();
        if(vaultIds.length != length) revert Errors.InvalidVaultId();
        if(onBehalfOfs.length != length) revert Errors.InvalidAddress();

        uint256 incomingTotalStakedTokens;
        uint256 incomingTotalBoostedStakedTokens;

        for(uint256 i; i < length; ++i) {

            bytes32 vaultId = vaultIds[i];
            address user = onBehalfOfs[i];
            uint256 stakedTokens = amounts[i];

            // cache vault and user data, reverts if vault does not exist
            (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, user, vaults, users);

            // vault cooldown activated: cannot stake
            if(vault.endTime > 0) revert Errors.VaultEndTimeSet(vaultId);

            // storage update: vault and user accounting across all active reward distributions
            _updateUserAccounts(activeDistributions, distributions, vaultAccounts, userAccounts, vault, userVaultAssets, params);

            // calc. boostedStakedTokens
            uint256 boostedStakedTokens = (stakedTokens * vault.totalBoostFactor) / params.PRECISION_BASE;
            
            // increment: vault
            vault.stakedTokens += stakedTokens;
            vault.boostedStakedTokens += boostedStakedTokens;

            // increment: user
            userVaultAssets.stakedTokens += stakedTokens;            

            // update storage: mappings 
            vaults[vaultId] = vault;
            users[user][vaultId] = userVaultAssets;
            
            // increment total tally
            incomingTotalStakedTokens += stakedTokens;    
            incomingTotalBoostedStakedTokens += boostedStakedTokens;
        }

        emit StakedOnBehalfOf(onBehalfOfs, vaultIds, amounts);

        return (incomingTotalStakedTokens, incomingTotalBoostedStakedTokens);
    }    

    function executeUpdateDistributionParams(
        uint256[] storage activeDistributions,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        uint256 distributionId, 
        uint256 newStartTime, 
        uint256 newEndTime, 
        uint256 newEmissionPerSecond,
        uint256 totalBoostedRealmPoints,
        uint256 totalBoostedStakedTokens,
        bool isPaused
    ) external returns(uint256) {
        
        DataTypes.Distribution memory distribution = distributions[distributionId];

        // Check distribution exists + not ended
        if(distribution.startTime == 0) revert Errors.NonExistentDistribution();
        if(block.timestamp >= distribution.endTime) revert Errors.DistributionEnded();

        // update distribution index
        distribution = _updateDistributionIndex(distribution, activeDistributions, totalBoostedRealmPoints, totalBoostedStakedTokens, isPaused);

        // startTime modification
        if(newStartTime > 0) {
            // Cannot update if distribution has already started
            if(block.timestamp >= distribution.startTime) revert Errors.DistributionStarted();
            
            // newStartTime must be a future time
            if(newStartTime <= block.timestamp) revert Errors.InvalidStartTime();

            distribution.startTime = newStartTime;
        }

        // staking power should not have an end time
        if(distributionId > 0){

            // endTime modification
            if(newEndTime > 0) {

                // cannot be in the past
                if(newEndTime <= block.timestamp) revert Errors.InvalidDistributionEndTime();

                // If only endTime is being updated, ensure it's after existing startTime
                if(newStartTime == 0 && newEndTime <= distribution.startTime) revert Errors.InvalidDistributionEndTime();
                
                // If both times are being updated, ensure end is after start
                if(newStartTime > 0 && newEndTime <= newStartTime) revert Errors.InvalidDistributionEndTime();

                // update endTime
                distribution.endTime = newEndTime;
            }
        }

        // emissionPerSecond modification 
        if(newEmissionPerSecond > 0) distribution.emissionPerSecond = newEmissionPerSecond;
            
        // recalc. new token requirements
        uint256 newTotalRequired = distribution.emissionPerSecond  * (distribution.endTime - distribution.lastUpdateTimeStamp);
        
        // invariant: newTotalRequired must non-zero
        if(newTotalRequired < 0) revert Errors.InvalidEmissionPerSecond();
        
        // update storage
        distributions[distributionId] = distribution;

        emit DistributionUpdated(distributionId, distribution.startTime, distribution.endTime, distribution.emissionPerSecond);

        return newTotalRequired;
    }

    function executeUpdateVaultsAndAccounts(
        uint256[] storage activeDistributions,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        
        DataTypes.UpdateAccountsIndexesParams memory params,
        bytes32[] calldata vaultIds,
        uint256 numOfVaults
    ) external {

        // cache active distributions to avoid incorrect processing of distributions due to .pop() [in _updateDistributionIndex]
        uint256 numOfDistributions = activeDistributions.length;
        uint256[] memory distributionsToProcess = new uint256[](numOfDistributions);
        for(uint256 i; i < numOfDistributions; ++i) {
            distributionsToProcess[i] = activeDistributions[i];
        }

        // process each distribution from our cached array
        for (uint256 i; i < numOfDistributions; ++i) {
            uint256 distributionId = distributionsToProcess[i];   
            
            DataTypes.Distribution memory distribution_ = distributions[distributionId];

            // Update distribution first
            DataTypes.Distribution memory distribution = _updateDistributionIndex(distribution_, activeDistributions, params.totalBoostedRealmPoints, params.totalBoostedStakedTokens, params.isPaused);

            // Then update all vault accounts for this distribution
            for(uint256 j; j < numOfVaults; ++j) {

                // get vault and vault account from storage
                bytes32 vaultId = vaultIds[j];
                DataTypes.Vault memory vault = vaults[vaultId];
                DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[vaultId][distributionId];
                
                // vault has been removed from circulation: skip
                if(vault.removed == 1) continue;

                // Update storage: vault account 
                (DataTypes.VaultAccount memory vaultAccount,) = _updateVaultAccount(vault, vaultAccount_, distribution, activeDistributions, params);
                vaultAccounts[vaultId][distributionId] = vaultAccount;

                // Update distribution storage if changed
                if(distribution.lastUpdateTimeStamp > distribution_.lastUpdateTimeStamp) {
                    distributions[distributionId] = distribution;
                }
            }
        }
    }

    function executeUpdateDistributionIndex(
        uint256[] storage activeDistributions,
        DataTypes.Distribution memory distribution,
        uint256 totalBoostedRealmPoints,
        uint256 totalBoostedStakedTokens,
        bool isPaused
    ) external returns(DataTypes.Distribution memory) {

        // update distribution index
        distribution = _updateDistributionIndex(distribution, activeDistributions, totalBoostedRealmPoints, totalBoostedStakedTokens, isPaused);

        return distribution;
    }

    function viewClaimRewards(        
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,

        DataTypes.UpdateAccountsIndexesParams memory params,
        uint256 distributionId
    ) external view returns (uint256) {
        
        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(params.vaultId, params.user, vaults, users);
        
        // get corresponding user+vault account for this active distribution 
        DataTypes.Distribution memory distribution = distributions[distributionId];
        DataTypes.VaultAccount memory vaultAccount = vaultAccounts[params.vaultId][distributionId];
        DataTypes.UserAccount memory userAccount = userAccounts[params.user][params.vaultId][distributionId];

        // only update specified distribution, and its accounts
        (userAccount, vaultAccount, distribution) 
            = _viewUserAccount(userVaultAssets, userAccount, vault, vaultAccount, distribution, params);

        //----------------------- calc. and update vault and user accounts ------------------------

        uint256 totalUnclaimedRewards;
        
        // staking MOCA rewards
        if (userAccount.accStakingRewards > userAccount.claimedStakingRewards) {
            uint256 unclaimedRewards = userAccount.accStakingRewards - userAccount.claimedStakingRewards;
            totalUnclaimedRewards += unclaimedRewards;
        }

        // staking RP rewards 
        if (userAccount.accRealmPointsRewards > userAccount.claimedRealmPointsRewards) {
            uint256 unclaimedRpRewards = userAccount.accRealmPointsRewards - userAccount.claimedRealmPointsRewards;
            totalUnclaimedRewards += unclaimedRpRewards;
        }

        // staking NFT rewards
        if (userAccount.accNftStakingRewards > userAccount.claimedNftRewards) {
            uint256 unclaimedNftRewards = userAccount.accNftStakingRewards - userAccount.claimedNftRewards;
            totalUnclaimedRewards += unclaimedNftRewards;
        }

        // creator rewards
        if (vault.creator == params.user) {
            uint256 unclaimedCreatorRewards = vaultAccount.accCreatorRewards - userAccount.claimedCreatorRewards;
            if(unclaimedCreatorRewards > 0) totalUnclaimedRewards += unclaimedCreatorRewards;
        }
        
        // rebase totalUnclaimedRewards to native precision
        uint256 totalUnclaimedRewardsInNative;
        if(totalUnclaimedRewards > 0) {
            totalUnclaimedRewardsInNative = totalUnclaimedRewards * distribution.TOKEN_PRECISION / 1E18;
        }

        return totalUnclaimedRewardsInNative;
    }

//-----------------------------------internal-------------------------------------------  

    function _updateDistributionIndex(
        DataTypes.Distribution memory distribution, 
        uint256[] storage activeDistributions, 
        uint256 totalBoostedRealmPoints, 
        uint256 totalBoostedStakedTokens,
        bool isPaused
    ) internal returns (DataTypes.Distribution memory) {
        
        // if paused, do not update distribution
        if(isPaused) return distribution;

        // distribution already updated
        if(distribution.lastUpdateTimeStamp == block.timestamp) return distribution;

        // distribution has not started
        if(block.timestamp < distribution.startTime) return distribution;

        // distribution has ended: does not apply to staking power, distributionId == 0
        if (distribution.endTime > 0 && block.timestamp >= distribution.endTime) {

            // If this is the first update after distribution ended, do final update to endTime
            if (distribution.lastUpdateTimeStamp < distribution.endTime) {
                
                // distributions w/ endTimes involve tokens, not realmPoints: use totalBoostedStakedTokens
                (uint256 finalIndex, /*currentTimestamp*/, uint256 finalEmitted) = _calculateDistributionIndex(distribution, totalBoostedStakedTokens);
                
                emit DistributionIndexUpdated(distribution.distributionId, distribution.endTime, distribution.index, finalIndex);

                distribution.index = finalIndex;
                distribution.totalEmitted += finalEmitted;
                distribution.lastUpdateTimeStamp = distribution.endTime;               
                
                // Remove from active distributions and mark as completed
                for (uint256 i; i < activeDistributions.length; ++i) {
                    if (activeDistributions[i] == distribution.distributionId) {
                        // Move last element to current position and pop
                        activeDistributions[i] = activeDistributions[activeDistributions.length - 1];
                        activeDistributions.pop();
                        break;
                    }
                }

                emit DistributionCompleted(distribution.distributionId, distribution.endTime, distribution.totalEmitted);
            }

            return distribution;
        }    

        // ..... Normal update for active distributions: could be for both tokens and realmPoints .....

        uint256 totalBoostedBalance = distribution.distributionId == 0 ? totalBoostedRealmPoints : totalBoostedStakedTokens;
        (uint256 nextIndex, uint256 currentTimestamp, uint256 emittedRewards) = _calculateDistributionIndex(distribution, totalBoostedBalance);
        
        if (nextIndex > distribution.index) {

            emit DistributionIndexUpdated(distribution.distributionId, currentTimestamp, distribution.index, nextIndex);

            distribution.index = nextIndex;
            distribution.totalEmitted += emittedRewards;
            distribution.lastUpdateTimeStamp = currentTimestamp;
        }

        return distribution;
    }

    /**
     * @dev Calculates the latest distribution index and emitted rewards since last update
     * @param distribution The distribution struct containing current state
     * @param totalBalance Total boosted balance (either tokens or realm points) for the distribution
     * @return nextIndex The updated distribution index
     * @return currentTimestamp The timestamp used for the calculation (capped by distribution/contract end time)
     * @return emittedRewards The total rewards emitted since last update
     */
    function _calculateDistributionIndex(DataTypes.Distribution memory distribution, uint256 totalBalance) internal view returns (uint256, uint256, uint256) {
        if (
            totalBalance == 0                                              // nothing has been staked
            || distribution.emissionPerSecond == 0                         // 0 emissions. no rewards setup.
            || distribution.lastUpdateTimeStamp == block.timestamp         // distribution already updated
        ) {
            return (distribution.index, block.timestamp, 0);                       
        }

        uint256 currentTimestamp;
        
        // Token distributions will have endTime set; use it as the cap
        if(distribution.endTime > 0) {
            currentTimestamp = block.timestamp > distribution.endTime ? distribution.endTime : block.timestamp;
        }
        // Staking Power will not have endTime set; use current block timestamp
        else {
            currentTimestamp = block.timestamp;
        }

        uint256 timeDelta = currentTimestamp - distribution.lastUpdateTimeStamp;
        
        // emissionPerSecond expressed w/ full token precision 
        uint256 emittedRewards = distribution.emissionPerSecond * timeDelta;
        
        // rebase to 1e18: match totalBalance precision
        uint256 emittedRewardsRebased = (emittedRewards * 1E18) / distribution.TOKEN_PRECISION;

        //note: indexes are denominated in 1E18
        uint256 nextDistributionIndex = ((emittedRewardsRebased * 1E18) / totalBalance) + distribution.index;        

        return (nextDistributionIndex, currentTimestamp, emittedRewards);
    }

    // update specified vault account
    // returns updated vault account and updated distribution structs 
    function _updateVaultAccount(
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount, 
        DataTypes.Distribution memory distribution_,
        uint256[] storage activeDistributions,
        DataTypes.UpdateAccountsIndexesParams memory params
    ) internal returns (DataTypes.VaultAccount memory, DataTypes.Distribution memory) {

        // get latest distributionIndex, if not already updated
        DataTypes.Distribution memory distribution = _updateDistributionIndex(
            distribution_, 
            activeDistributions, 
            params.totalBoostedRealmPoints, 
            params.totalBoostedStakedTokens,
            params.isPaused
        );

        // vault already been updated by a prior txn; skip updating vaultAccount
        if(distribution.index == vaultAccount.index) return (vaultAccount, distribution);

        // vault has been removed from circulation: final update done by endVaults()
        if(vault.removed == 1) return (vaultAccount, distribution);

        // If vault has ended, vaultIndex should not be updated, beyond the final update.
        /** note:
            - vaults are removed from circulation via endVaults()
            - endVaults() is responsible for the final update and setting `vault.removed = 1`
            - final update involves updating all vault accounts, indexes and removing assets from global state
            - we cannot be sure that endVaults() would be called precisely at the endTime for each vault
            - therefore we must allow for some drift
            - as such, the check below cannot be implemented. 
        */
        //if(vault.endTime > 0 && block.timestamp >= vault.endTime) return (vaultAccount, distribution);

        // STAKING POWER: staked realm points | TOKENS: staked moca tokens
        uint256 boostedBalance = distribution.distributionId == 0 ? vault.boostedRealmPoints : vault.boostedStakedTokens;
        
        // nothing staked, skip update
        if(boostedBalance == 0) {
            vaultAccount.index = distribution.index;
            return (vaultAccount, distribution);  
        }

        // note: totalAccRewards expressed in 1E18 precision 
        uint256 totalAccRewards = _calculateRewards(boostedBalance, distribution.index, vaultAccount.index, 1E18);

        // update vault rewards + fees
        uint256 accCreatorFee; 
        uint256 accTotalNftFee;
        uint256 accRealmPointsFee;

        // calc. creator fees
        if(vault.creatorFeeFactor > 0) {
            // fees are kept in 1E18 during intermediate calculations
            accCreatorFee = (totalAccRewards * vault.creatorFeeFactor) / params.PRECISION_BASE;
        }

        // nft fees accrued only if there were staked NFTs
        if(vault.stakedNfts > 0) {
            if(vault.nftFeeFactor > 0) {

                // indexes are denominated in 1E18 | fees are kept in 1E18 during intermediate calculations
                accTotalNftFee = (totalAccRewards * vault.nftFeeFactor) / params.PRECISION_BASE;
                vaultAccount.nftIndex += (accTotalNftFee / vault.stakedNfts);      // nftIndex: rewardsAccPerNFT            
            }
        }

        // rp fees accrued only if there were staked RP 
        if(vault.stakedRealmPoints > 0) {
            if(vault.realmPointsFeeFactor > 0) {

                // indexes are denominated in 1E18 | fees are kept in 1E18 during intermediate calculations | realmPoints are denominated in 1E18
                accRealmPointsFee = (totalAccRewards * vault.realmPointsFeeFactor) / params.PRECISION_BASE;
                vaultAccount.rpIndex += (accRealmPointsFee * 1E18) / vault.stakedRealmPoints;      // rpIndex: rewardsAccPerRP
            }
        } 
        
        // book rewards: total, creator, nft, rp | expressed in 1E18 precision
        vaultAccount.totalAccRewards += totalAccRewards;
        vaultAccount.accCreatorRewards += accCreatorFee;
        vaultAccount.accNftStakingRewards += accTotalNftFee;
        vaultAccount.accRealmPointsRewards += accRealmPointsFee;

        // reference for moca stakers to calc. rewards less of fees | rewardsAccPerUnitStaked expressed in 1E18 precision
        if(vault.stakedTokens > 0) {    
            vaultAccount.rewardsAccPerUnitStaked += ((totalAccRewards - accCreatorFee - accTotalNftFee - accRealmPointsFee) * 1E18) / vault.stakedTokens;
        }

        // update vaultIndex
        vaultAccount.index = distribution.index;

        emit VaultAccountUpdated(params.vaultId, distribution.distributionId, totalAccRewards, accCreatorFee, accTotalNftFee, accRealmPointsFee);

        return (vaultAccount, distribution);
    }

    function _updateUserAccount(
        uint256[] storage activeDistributions,
        DataTypes.User memory user, 
        DataTypes.UserAccount memory userAccount,
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount_, 
        DataTypes.Distribution memory distribution_,
        DataTypes.UpdateAccountsIndexesParams memory params
    ) internal returns (DataTypes.UserAccount memory, DataTypes.VaultAccount memory, DataTypes.Distribution memory) {
        
        // get updated vaultAccount and distribution
        (DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _updateVaultAccount(vault, vaultAccount_, distribution_, activeDistributions, params);
        
        // index in 1E18 precision
        uint256 newUserIndex = vaultAccount.rewardsAccPerUnitStaked;
        
        // all rewards in 1E18 precision
        uint256 accruedStakingRewards;
        uint256 accNftStakingRewards;
        uint256 accRealmPointsRewards;

        // users whom staked tokens are eligible for rewards less of fees
        if(user.stakedTokens > 0) {
            if(newUserIndex > userAccount.index) { 
                accruedStakingRewards = _calculateRewards(user.stakedTokens, newUserIndex, userAccount.index, 1E18);
                userAccount.accStakingRewards += accruedStakingRewards;
            }
        }

        // user's accrued rewards for staked NFTs 
        uint256 userStakedNfts = user.tokenIds.length;
        if(userStakedNfts > 0) {
            if(vaultAccount.nftIndex > userAccount.nftIndex){
                accNftStakingRewards = (vaultAccount.nftIndex - userAccount.nftIndex) * userStakedNfts;
                userAccount.accNftStakingRewards += accNftStakingRewards;
            }
        }

        // user's accrued rewards from staked RP
        if(user.stakedRealmPoints > 0){
            // vaultAccount.rewardsAccPerUnitStaked could be incremented, w/out incrementing vaultAccount.rpIndex; 0 feeFactor.
            if(vaultAccount.rpIndex > userAccount.rpIndex) {    
            
                // users whom staked RP are eligible for a portion of RP fees 
                accRealmPointsRewards = _calculateRewards(user.stakedRealmPoints, vaultAccount.rpIndex, userAccount.rpIndex, 1E18);
                userAccount.accRealmPointsRewards += accRealmPointsRewards;
            }
        }
        
        // update user indexes | all in 1E18 precision
        userAccount.index = vaultAccount.rewardsAccPerUnitStaked;   // less of fees
        userAccount.nftIndex = vaultAccount.nftIndex;
        userAccount.rpIndex = vaultAccount.rpIndex;

        emit UserAccountUpdated(params.user, params.vaultId, distribution.distributionId, accruedStakingRewards, accNftStakingRewards, accRealmPointsRewards);

        return (userAccount, vaultAccount, distribution);
    }

    /// called prior to affecting any state change to a user
    /// applies fees onto the vaultIndex to return the userIndex
    function _updateUserAccounts(
        uint256[] storage activeDistributions,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,
        
        DataTypes.Vault memory vault, 
        DataTypes.User memory userVaultAssets,
        DataTypes.UpdateAccountsIndexesParams memory params
    ) internal {

        /** user -> vaultId (stake)
            - this changes the composition for both the user and vault
            - before booking the change we must update all vault and user accounts
            -- distr_0: distriData, vaultAccount, userAccount
            -- distr_1: distriData, vaultAccount, userAccount

            loop thru userAccounts -> vaultAccounts -> distri
        */

        // cache active distributions to avoid incorrect processing of distributions due to .pop() [in _updateDistributionIndex]
        uint256 numOfDistributions = activeDistributions.length;
        uint256[] memory distributionsToProcess = new uint256[](numOfDistributions);
        for(uint256 i; i < numOfDistributions; ++i) {
            distributionsToProcess[i] = activeDistributions[i];
        }

        // process each distribution from our cached array
        for (uint256 i; i < numOfDistributions; ++i) {
            uint256 distributionId = distributionsToProcess[i];   

            // get corresponding user+vault account for this active distribution 
            DataTypes.Distribution memory distribution = distributions[distributionId];
            DataTypes.VaultAccount memory vaultAccount = vaultAccounts[params.vaultId][distributionId];
            DataTypes.UserAccount memory userAccount = userAccounts[params.user][params.vaultId][distributionId];

            (
                userAccount, 
                vaultAccount, 
                distribution
            ) = _updateUserAccount(activeDistributions, userVaultAssets, userAccount, vault, vaultAccount, distribution, params);

            //update storage: accounts and distributions
            distributions[distributionId] = distribution;     
            vaultAccounts[params.vaultId][distributionId] = vaultAccount;  
            userAccounts[params.user][params.vaultId][distributionId] = userAccount;
        }
    }

    // for calc. rewards from index deltas. assumes tt indexes are expressed in the same precision.
    function _calculateRewards(uint256 balance, uint256 currentIndex, uint256 priorIndex, uint256 PRECISION) internal pure returns (uint256) {
        return (balance * (currentIndex - priorIndex)) / PRECISION;
    }


    ///@dev cache vault and user structs from storage to memory. checks that vault exists, else reverts.
    function _cache(
        bytes32 vaultId, address user,
        mapping(bytes32 vaultId => DataTypes.Vault vault) storage vaults,
        mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) storage users
    ) internal view returns(DataTypes.User memory, DataTypes.Vault memory) {

        // ensure vault exists
        DataTypes.Vault memory vault = vaults[vaultId];
        if(vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);

        // get vault level user data
        DataTypes.User memory userVaultAssets = users[user][vaultId];

        return (userVaultAssets, vault);
    }

    ///@dev concat two uint256 arrays: [1,2,3],[4,5] -> [1,2,3,4,5]
    function _concatArrays(uint256[] memory arr1, uint256[] memory arr2) internal pure returns(uint256[] memory) {
        
        // create resulting arr
        uint256 len1 = arr1.length;
        uint256 len2 = arr2.length;
        uint256[] memory resArr = new uint256[](len1 + len2);
        
        uint256 i;
        for (; i < len1; i++) {
            resArr[i] = arr1[i];
        }
        
        uint256 j;
        while (j < len2) {
            resArr[i++] = arr2[j++];
        }

        return resArr;
    }

    ///@dev will revert if arrToRemove contains elements not found within originalArr
    ///@dev reversion due to resArr accessing an invalid index
    function _removeFromArray(uint256[] memory originalArr, uint256[] memory arrToRemove) internal pure returns (uint256[] memory) {
        uint256 originalLength = originalArr.length;
        uint256 toRemoveLength = arrToRemove.length;
        
        uint256[] memory resArr = new uint256[](originalLength - toRemoveLength);
        uint256 k;

        for(uint256 i; i < originalLength; ++i){
            bool shouldKeep = true;
            
            // Check if current element should be removed
            for(uint256 j; j < toRemoveLength; ++j){
                if(originalArr[i] == arrToRemove[j]){
                    shouldKeep = false;
                    break;
                } 
            }

            if(shouldKeep) {
                resArr[k] = originalArr[i];
                ++k;
            }            
        }

        return resArr;
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/
    
    function viewUserAccount(        
        DataTypes.User memory user, 
        DataTypes.UserAccount memory userAccount,
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount_, 
        DataTypes.Distribution memory distribution_,
        DataTypes.UpdateAccountsIndexesParams memory params
    ) external view returns (DataTypes.UserAccount memory, DataTypes.VaultAccount memory, DataTypes.Distribution memory) {
        return _viewUserAccount(user, userAccount, vault, vaultAccount_, distribution_, params);
    }

    function _viewUserAccount(
        DataTypes.User memory user, 
        DataTypes.UserAccount memory userAccount,
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount_, 
        DataTypes.Distribution memory distribution_,
        DataTypes.UpdateAccountsIndexesParams memory params
    ) internal view returns (DataTypes.UserAccount memory, DataTypes.VaultAccount memory, DataTypes.Distribution memory) {
        
        // get updated vaultAccount and distribution
        (DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _viewVaultAccount(vault, vaultAccount_, distribution_, params);

        // 1E18 precision
        uint256 newUserIndex = vaultAccount.rewardsAccPerUnitStaked;
        
        // users whom staked tokens are eligible for rewards less of fees 
        if(newUserIndex > userAccount.index) { 
            if(user.stakedTokens > 0) {
                uint256 accruedStakingRewards = _calculateRewards(user.stakedTokens, newUserIndex, userAccount.index, 1E18);
                userAccount.accStakingRewards += accruedStakingRewards;
            }
        }
        
        // user's accrued rewards for staked NFTs 
        uint256 userStakedNfts = user.tokenIds.length;
        if(userStakedNfts > 0) {
            if(vaultAccount.nftIndex > userAccount.nftIndex){
                uint256 accNftStakingRewards = (vaultAccount.nftIndex - userAccount.nftIndex) * userStakedNfts;
                userAccount.accNftStakingRewards += accNftStakingRewards;
            }
        }

        // user's accrued rewards from staked RP
        if(user.stakedRealmPoints > 0){
            // vaultAccount.rewardsAccPerUnitStaked could be incremented, w/out incrementing vaultAccount.rpIndex; 0 feeFactor.
            if(vaultAccount.rpIndex > userAccount.rpIndex) {    

                // users whom staked RP are eligible for a portion of RP fees 
                uint256 accRealmPointsRewards = _calculateRewards(user.stakedRealmPoints, vaultAccount.rpIndex, userAccount.rpIndex, 1E18);
                userAccount.accRealmPointsRewards += accRealmPointsRewards;
            }
        }
        
        // update user indexes | all in 1E18 precision
        userAccount.index = vaultAccount.rewardsAccPerUnitStaked;   // less of fees
        userAccount.nftIndex = vaultAccount.nftIndex;
        userAccount.rpIndex = vaultAccount.rpIndex;

        return (userAccount, vaultAccount, distribution);
    }

    function viewVaultAccount(
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount, 
        DataTypes.Distribution memory distribution_,
        DataTypes.UpdateAccountsIndexesParams memory params
    ) external view returns (DataTypes.VaultAccount memory, DataTypes.Distribution memory) {
        return _viewVaultAccount(vault, vaultAccount, distribution_, params);
    }

    function _viewVaultAccount(
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount, 
        DataTypes.Distribution memory distribution_,
        DataTypes.UpdateAccountsIndexesParams memory params
    ) internal view returns (DataTypes.VaultAccount memory, DataTypes.Distribution memory) {

        // get latest distributionIndex, if not already updated
        DataTypes.Distribution memory distribution = _viewDistributionIndex(
            distribution_, 
            params.totalBoostedRealmPoints, 
            params.totalBoostedStakedTokens
        );

        // vault already been updated by a prior txn; skip updating vaultAccount
        if(distribution.index == vaultAccount.index) return (vaultAccount, distribution);

        // vault has been removed from circulation: final update done by endVaults()
        if(vault.removed == 1) return (vaultAccount, distribution);
        
        // STAKING POWER: staked realm points | TOKENS: staked moca tokens
        uint256 boostedBalance = distribution.distributionId == 0 ? vault.boostedRealmPoints : vault.boostedStakedTokens;
        
        // nothing staked: update main reference index and return
        if(boostedBalance == 0) {
            vaultAccount.index = distribution.index;
            return (vaultAccount, distribution);  
        }

        // Calculate rewards using the balance at the time they were accrued
        uint256 totalAccRewards = _calculateRewards(boostedBalance, distribution.index, vaultAccount.index, 1E18);

        // update vault rewards + fees
        uint256 accCreatorFee; 
        uint256 accTotalNftFee;
        uint256 accRealmPointsFee;

        // calc. creator fees
        if(vault.creatorFeeFactor > 0) {
            // fees are kept in 1E18 during intermediate calculations
            accCreatorFee = (totalAccRewards * vault.creatorFeeFactor) / params.PRECISION_BASE;
        }

        // nft fees accrued only if there were staked NFTs
        if(vault.stakedNfts > 0) {
            if(vault.nftFeeFactor > 0) {
                // indexes are denominated in 1E18 | fees are kept in 1E18 during intermediate calculations
                accTotalNftFee = (totalAccRewards * vault.nftFeeFactor) / params.PRECISION_BASE;
                vaultAccount.nftIndex += (accTotalNftFee / vault.stakedNfts);   // nftIndex: rewardsAccPerNFT    
            }
        }

        // rp fees accrued only if there were staked RP 
        if(vault.stakedRealmPoints > 0) {
            if(vault.realmPointsFeeFactor > 0) {
                // indexes are denominated in 1E18 | fees are kept in 1E18 during intermediate calculations | realmPoints are denominated in 1E18
                accRealmPointsFee = (totalAccRewards * vault.realmPointsFeeFactor) / params.PRECISION_BASE;
                vaultAccount.rpIndex += (accRealmPointsFee * 1E18) / vault.stakedRealmPoints;              // rpIndex: rewardsAccPerRP
            }
        } 

        // book rewards: total, creator, nft, rp | expressed in 1E18 precision
        vaultAccount.totalAccRewards += totalAccRewards;
        vaultAccount.accCreatorRewards += accCreatorFee;
        vaultAccount.accNftStakingRewards += accTotalNftFee;
        vaultAccount.accRealmPointsRewards += accRealmPointsFee;

        // reference for moca stakers to calc. rewards less of fees | rewardsAccPerUnitStaked expressed in 1E18 precision
        if(vault.stakedTokens > 0){
            vaultAccount.rewardsAccPerUnitStaked += ((totalAccRewards - accCreatorFee - accTotalNftFee - accRealmPointsFee) * 1E18) / vault.stakedTokens;
        }

        // update vaultIndex
        vaultAccount.index = distribution.index;

        return (vaultAccount, distribution);
    }

    function _viewDistributionIndex(
        DataTypes.Distribution memory distribution, 
        uint256 totalBoostedRealmPoints, 
        uint256 totalBoostedStakedTokens
    ) internal view returns (DataTypes.Distribution memory) {
        
        // distribution already updated
        if(distribution.lastUpdateTimeStamp == block.timestamp) return distribution;

        // distribution has not started
        if(block.timestamp < distribution.startTime) return distribution;

        // index expressed in 1E18
        uint256 totalBoostedBalance = distribution.distributionId == 0 ? totalBoostedRealmPoints : totalBoostedStakedTokens;
        (uint256 nextIndex, uint256 currentTimestamp, uint256 emittedRewards) = _calculateDistributionIndex(distribution, totalBoostedBalance);

        if (nextIndex > distribution.index) {

            distribution.index = nextIndex;
            distribution.totalEmitted += emittedRewards;
            distribution.lastUpdateTimeStamp = currentTimestamp;
        }

        return distribution;
    } 

}