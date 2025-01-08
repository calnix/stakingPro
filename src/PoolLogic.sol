// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import './Events.sol';
import {Errors} from './Errors.sol';
import {DataTypes} from './DataTypes.sol';

import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

library PoolLogic {
    using SafeERC20 for IERC20;

    function executeUpdateAccountsForAllDistributions(
        uint256[] storage activeDistributions,
        mapping(uint256 distributionId => DataTypes.Distribution distribution) storage distributions,
        mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) storage vaultAccounts,
        mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) storage userAccounts,
        DataTypes.User memory user,
        DataTypes.Vault memory vault,
        DataTypes.ExecuteUpdateAccountsIndexesParams memory params
    ) external {

        // storage update: vault and user accounting across all active reward distributions
        _updateUserAccounts(activeDistributions, distributions, vaultAccounts, userAccounts, vault, user, params);

    }

    function executeUpdateAccountsForOneDistribution(
        uint256[] storage activeDistributions,
        DataTypes.Distribution memory distribution,
        DataTypes.Vault memory vault,
        DataTypes.User memory user,
        DataTypes.UserAccount memory userAccount,
        DataTypes.VaultAccount memory vaultAccount,
        DataTypes.ExecuteUpdateAccountsIndexesParams memory params
    ) external returns (DataTypes.UserAccount memory, DataTypes.VaultAccount memory, DataTypes.Distribution memory){

        return _updateUserAccount(activeDistributions, user, userAccount, vault, vaultAccount, distribution, params);
    }

    // note: does not update storage, only returns the updated distribution
    function executeUpdateDistributionIndex(
        uint256[] storage activeDistributions,
        DataTypes.Distribution memory distribution,
        uint256 totalBoostedRealmPoints,
        uint256 totalBoostedStakedTokens
    ) external returns (DataTypes.Distribution memory) {

        return _updateDistributionIndex(distribution, activeDistributions, totalBoostedRealmPoints, totalBoostedStakedTokens);
    }

    function executeUpdateVaultAccount(        
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount, 
        DataTypes.Distribution memory distribution_,
        uint256[] storage activeDistributions,
        DataTypes.ExecuteUpdateAccountsIndexesParams memory params)
        external returns (DataTypes.VaultAccount memory, DataTypes.Distribution memory) {

        return _updateVaultAccount(vault, vaultAccount, distribution_, activeDistributions, params);
    }


//-----------------------------------internal-------------------------------------------

    //note: does not update storage, only returns the updated distribution
    function _updateDistributionIndex(DataTypes.Distribution memory distribution, uint256[] storage activeDistributions, uint256 totalBoostedRealmPoints, uint256 totalBoostedStakedTokens) internal returns (DataTypes.Distribution memory) {

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

                distribution.index = finalIndex;
                distribution.totalEmitted += finalEmitted;
                distribution.lastUpdateTimeStamp = distribution.endTime;
                
                emit DistributionIndexUpdated(distribution.distributionId, distribution.lastUpdateTimeStamp, distribution.index, finalIndex);
                
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

            distribution.index = nextIndex;
            distribution.totalEmitted += emittedRewards;
            distribution.lastUpdateTimeStamp = currentTimestamp;

            emit DistributionIndexUpdated(distribution.distributionId, distribution.lastUpdateTimeStamp, distribution.index, nextIndex);
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
            return (distribution.index, distribution.lastUpdateTimeStamp, 0);                       
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
        uint256 emittedRewards;
        unchecked {
            // Overflow is unlikely as timeDelta is bounded by block times
            emittedRewards = distribution.emissionPerSecond * timeDelta;
        }

        /* note: totalBalance is expressed 1e18. 
                 emittedRewards is variable as per distribution.TOKEN_PRECISION
                 normalize totalBalance to reward token's native precision
                 why: paying out rewards token, standardize to that */
        uint256 totalBalanceRebased = (totalBalance * distribution.TOKEN_PRECISION) / 1E18;
    
        //note: indexes are denominated in the distribution's precision
        uint256 nextDistributionIndex = ((emittedRewards * distribution.TOKEN_PRECISION) / totalBalanceRebased) + distribution.index; 

        return (nextDistributionIndex, currentTimestamp, emittedRewards);
    }


    // update specified vault account
    // returns updated vault account and updated distribution structs 
    function _updateVaultAccount(
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount, 
        DataTypes.Distribution memory distribution_,
        uint256[] storage activeDistributions,
        DataTypes.ExecuteUpdateAccountsIndexesParams memory params
        ) internal returns (DataTypes.VaultAccount memory, DataTypes.Distribution memory) {

        // get latest distributionIndex, if not already updated
        DataTypes.Distribution memory distribution = _updateDistributionIndex(distribution_, activeDistributions, params.totalBoostedRealmPoints, params.totalBoostedStakedTokens);
        
        // vault already been updated by a prior txn; skip updating vaultAccount
        if(distribution.index == vaultAccount.index) return (vaultAccount, distribution);

        // vault has been removed from circulation: final update done by endVaults()
        if(vault.removed == 1) return (vaultAccount, distribution);

        // If vault has ended, vaultIndex should not be updated, beyond the final update.
        /** note:
            - vaults are removed from circulation via endVaults
            - endVaults is responsible for the final update and setting `vault.removed = 1`
            - final update involves updating all vault accounts, indexes and removing assets from global state
            - we cannot be sure that endVaults would be called precisely at the endTime for each vault
            - therefore we must allow for some drift
            - as such, the check below cannot be implemented. 
         */
        //if(vault.endTime > 0 && block.timestamp >= vault.endTime) return (vaultAccount, distribution);
        
        /**note:
            - what about implementing the check with a buffer? 
            - e.g. if(vault.endTime > 0 && block.timestamp + 7 days >= vault.endTime)
            - this would allow for some drift, but not too much

            smart over/under updates (?)
            - under: update distri to vault.Endtime and update the vault indexes till endTime
            - over: update distri to block.timestamp and update the vault indexes till endTime
         */

        
        // update vault rewards + fees
        uint256 totalAccRewards; 
        uint256 accCreatorFee; 
        uint256 accTotalNftFee;
        uint256 accRealmPointsFee;

        // STAKING POWER: staked realm points | TOKENS: staked moca tokens
        uint256 boostedBalance = distribution.distributionId == 0 ? vault.boostedRealmPoints : vault.boostedStakedTokens;
        uint256 totalBalanceRebased = (boostedBalance * distribution.TOKEN_PRECISION) / 1E18;  
        // note: rewards calc. in reward token precision
        totalAccRewards = _calculateRewards(totalBalanceRebased, distribution.index, vaultAccount.index, distribution.TOKEN_PRECISION);

        // calc. creator fees
        if(vault.creatorFeeFactor > 0) {
            accCreatorFee = (totalAccRewards * vault.creatorFeeFactor) / params.PRECISION_BASE;
        }

        // nft fees accrued only if there were staked NFTs
        if(vault.stakedNfts > 0) {
            if(vault.nftFeeFactor > 0) {

                accTotalNftFee = (totalAccRewards * vault.nftFeeFactor) / params.PRECISION_BASE;
                vaultAccount.nftIndex += (accTotalNftFee / vault.stakedNfts);              // nftIndex: rewardsAccPerNFT
            }
        }

        // rp fees accrued only if there were staked RP 
        if(vault.stakedRealmPoints > 0) {
            if(vault.realmPointsFeeFactor > 0) {
                accRealmPointsFee = (totalAccRewards * vault.realmPointsFeeFactor) / params.PRECISION_BASE;

                // accRealmPointsFee is in reward token precision
                uint256 stakedRealmPointsRebased = (vault.stakedRealmPoints * distribution.TOKEN_PRECISION) / 1E18;  
                vaultAccount.rpIndex += (accRealmPointsFee / stakedRealmPointsRebased);              // rpIndex: rewardsAccPerRP
            }
        } 
        
        // book rewards: total, Creator, NFT, RealmPoints | expressed in distri token precision
        vaultAccount.totalAccRewards += totalAccRewards;
        vaultAccount.accCreatorRewards += accCreatorFee;
        vaultAccount.accNftStakingRewards += accTotalNftFee;
        vaultAccount.accRealmPointsRewards += accRealmPointsFee;

        // reference for moca stakers to calc. rewards net of fees
        uint256 totalStakedRebased = (vault.stakedTokens * distribution.TOKEN_PRECISION) / 1E18;
        vaultAccount.rewardsAccPerUnitStaked += (totalAccRewards - accCreatorFee - accTotalNftFee - accRealmPointsFee) / totalStakedRebased;  

        // update vaultIndex
        vaultAccount.index = distribution.index;

        // emit VaultIndexUpdated    

        return (vaultAccount, distribution);
    }

    function _updateUserAccount(
        uint256[] storage activeDistributions,
        DataTypes.User memory user, 
        DataTypes.UserAccount memory userAccount,
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount_, 
        DataTypes.Distribution memory distribution_,
        DataTypes.ExecuteUpdateAccountsIndexesParams memory params
        ) internal returns (DataTypes.UserAccount memory, DataTypes.VaultAccount memory, DataTypes.Distribution memory) {
        
        // get updated vaultAccount and distribution
        (DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _updateVaultAccount(vault, vaultAccount_, distribution_, activeDistributions, params);
        
        uint256 newUserIndex = vaultAccount.rewardsAccPerUnitStaked;

        // if this index has not been updated, the subsequent ones would not have. check once here, no need repeat
        if(userAccount.index != newUserIndex) { 

            if(user.stakedTokens > 0) {
                // users whom staked tokens are eligible for rewards less of fees
                uint256 balanceRebased = (user.stakedTokens * distribution.TOKEN_PRECISION) / 1E18;
                uint256 accruedRewards = _calculateRewards(balanceRebased, newUserIndex, userAccount.index, distribution.TOKEN_PRECISION);
                userAccount.accStakingRewards += accruedRewards;

                // emit RewardsAccrued(user, accruedRewards, distributionPrecision);
            }


            uint256 userStakedNfts = user.tokenIds.length;
            if(userStakedNfts > 0) {

                // total accrued rewards from staking NFTs
                uint256 accNftStakingRewards = (vaultAccount.nftIndex - userAccount.nftIndex) * userStakedNfts;
                userAccount.accNftStakingRewards += accNftStakingRewards;

                //emit NftRewardsAccrued(user, accNftStakingRewards);
            }


            if(user.stakedRealmPoints > 0){
                
                // users whom staked RP are eligible for a portion of RP fees
                uint256 totalStakedRpRebased = (vault.stakedRealmPoints * distribution.TOKEN_PRECISION) / 1E18;

                uint256 accRealmPointsRewards = (vaultAccount.rpIndex - userAccount.rpIndex) * totalStakedRpRebased;
                userAccount.accRealmPointsRewards += accRealmPointsRewards;

                //emit something
            }
        }

        // update user indexes
        userAccount.index = vaultAccount.rewardsAccPerUnitStaked;   // less of fees
        userAccount.nftIndex = vaultAccount.nftIndex;
        userAccount.rpIndex = vaultAccount.rpIndex;

        // emit UserIndexesUpdated(user, vault.vaultId, newUserIndex, newUserNftIndex, userInfo.accStakingRewards);

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
        DataTypes.ExecuteUpdateAccountsIndexesParams memory params
        ) internal {

        /** user -> vaultId (stake)
            - this changes the composition for both the user and vault
            - before booking the change we must update all vault and user accounts
            -- distr_0: distriData, vaultAccount, userAccount
            -- distr_1: distriData, vaultAccount, userAccount

            loop thru userAccounts -> vaultAccounts -> distri
         */

        // always > 0, staking power is setup on deployment
        uint256 numOfDistributions = activeDistributions.length;
        
        // update each user account, looping thru distributions
        for (uint256 i; i < numOfDistributions; ++i) {
             
            uint256 distributionId = activeDistributions[i];   

            // get corresponding user+vault account for this active distribution 
            DataTypes.Distribution memory distribution_ = distributions[distributionId];
            DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[params.vaultId][distributionId];
            DataTypes.UserAccount memory userAccount_ = userAccounts[params.user][params.vaultId][distributionId];

            
            (DataTypes.UserAccount memory userAccount, DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _updateUserAccount(activeDistributions, userVaultAssets, userAccount_, vault, vaultAccount_, distribution_, params);

            //update storage: accounts and distributions
            distributions[distributionId] = distribution;     
            vaultAccounts[params.vaultId][distributionId] = vaultAccount;  
            userAccounts[params.user][params.vaultId][distributionId] = userAccount;
        }
    }

    // for calc. rewards from index deltas. assumes tt indexes are expressed in the distribution's precision. therefore balance must be rebased to the same precision
    function _calculateRewards(uint256 balanceRebased, uint256 currentIndex, uint256 priorIndex, uint256 PRECISION) internal pure returns (uint256) {
        return (balanceRebased * (currentIndex - priorIndex)) / PRECISION;
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
}
