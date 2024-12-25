# discarded fns

```solidity
    // update all active distributions: book prior rewards, based on prior alloc points 
    function _updateDistributionIndexes() internal {
        if(activeDistributions.length == 0) revert NoActiveDistributions(); // at least staking power should have been setup on deployment

        uint256 numOfDistributions = activeDistributions.length;

        for(uint256 i; i < numOfDistributions; ++i) {

            // update storage
            distributions[activeDistributions[i]] = _updateDistributionIndex(distributions[activeDistributions[i]]);
        }
    }
```

```solidity
    // update all vault accounts per active distribution, for specified vault
    function _updateVaultAllAccounts(bytes32 vaultId) internal {

        DataTypes.Vault memory vault = vaults[vaultId];

        // always > 0, staking power is setup on deployment
        uint256 numOfActiveVaults = activeDistributions.length;
        
        // update each vault account
        for (uint256 i; i < numOfActiveVaults; i++) {

            DataTypes.Distribution memory distribution_ = distributions[activeDistributions[i]];
            // get vault account for active distribution
            DataTypes.VaultData memory vaultAccount = vaultAccounts[vaultId][activeDistributions[i]];

            // get latest distributionIndex
            DataTypes.Distribution memory distribution = _updateDistributionIndex(distribution_);
            
            // vault already been updated by a prior txn; skip updating
            if(distribution.index == vaultAccount.index) continue;

            // If vault has ended, vaultIndex should not be updated, beyond the final update.
            if(block.timestamp >= vault.endTime) continue;

            // update vault rewards + fees
            uint256 accruedRewards; 
            uint256 accCreatorFee; 
            uint256 accTotalNftFee;
            uint256 accRealmPointsFee;

            // Calculate rewards based on distribution type (staking power or token rewards)
            uint256 stakedBalance = distribution.chainId == 0 ? vault.boostedRealmPoints : vault.boostedStakedTokens;
            accruedRewards = _calculateRewards(stakedBalance, distribution.index, vaultAccount.index);

            // calc. creator fees
            if(vault.creatorFeeFactor > 0) {
                accCreatorFee = (accruedRewards * vault.creatorFeeFactor) / distribution.TOKEN_PRECISION;
            }

            // nft fees accrued only if there were staked NFTs
            if(vault.stakedNfts > 0) {
                if(vault.nftFeeFactor > 0) {
                    accTotalNftFee = (accruedRewards * vault.nftFeeFactor) / distribution.TOKEN_PRECISION;

                    vaultAccount.nftIndex += (accTotalNftFee / vault.stakedNfts);              // nftIndex: rewardsAccPerNFT
                }
            }

            if(vault.realmPointsFeeFactor > 0) {
                accRealmPointsFee = (accruedRewards * vault.realmPointsFeeFactor) / distribution.TOKEN_PRECISION;
            } 
            
            // book rewards: total, Creator, NFT, RealmPoints
            vaultAccount.totalAccRewards += accruedRewards;
            vaultAccount.accCreatorRewards += accCreatorFee;
            vaultAccount.accNftStakingRewards += accTotalNftFee;
            vaultAccount.accRealmPointsRewards += accRealmPointsFee;

            // reference for users' to calc. rewards: rewards net of fees
            vaultAccount.rewardsAccPerUnitStaked += ((accruedRewards - accCreatorFee - accTotalNftFee - accRealmPointsFee) * TOKEN_PRECISION) / stakedBalance;

            // update vaultIndex
            vaultAccount.vaultIndex = distribution.index;

            // emit VaultIndexUpdated

            // update storage
            distributions[activeDistributions[i]] = distribution;     
            vaultAccounts[vaultId][activeDistributions[i]] = vaultAccount;   
        }   
    }
```
