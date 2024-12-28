# Design considerations

## 1. Decimal Precision

indexes are denominated in the distribution's precision
rewards calculated and stored in the distribution's precision

At the end of the day, we are paying out in native precision, so, standardize to that.

However, when calculating rewards, in both `_updateUserAccount` and `_updateVaultAccount`, we must convert the decimal precision of stakedBase to the distribution's precision.
Since `stakedBase` is denominated in the native precision, we must convert it to the distribution's precision.

If the distribution's precision is lower than 1E18, we are rounding down `stakedBase`, and therefore calculated rewards will be lower than they should be.
If the distribution's precision is higher than 1E18, we are simply adding zeros to `stakedBase`; this does not impact the rewards calculation. **[TODO: check if this is correct]**

```solidity
    uint256 balanceRebased = (user.stakedTokens * distribution.TOKEN_PRECISION) / 1E18;
    uint256 accruedRewards = _calculateRewards(balanceRebased, newUserIndex, userAccount.index);
                
    // for calc. rewards from index deltas. assumes tt indexes are expressed in the distribution's precision. therefore balance must be rebased to the same precision
    function _calculateRewards(uint256 balanceRebased, uint256 currentIndex, uint256 priorIndex) internal pure returns (uint256) {
        return (balanceRebased * (currentIndex - priorIndex)) / 1E18;
    }

```

Also, isn't the division by 1E18 in `_calculateRewards` wrong?


in `_updateVaultAccount::_calculateRewards`

`_calculateRewards`
- uses delta in index to calculate rewards accrued to vault
- (balance * (currentIndex - priorIndex)) / 1E18;



to standardize to the rewards token's precision, 
we must convert the decimal precision of stakedBase

this impacts _calculateDistributionIndex and _calculateRewards

staking base gets rounded down: 

```solidity

contract PrecisionConversion {

    uint public upper;  // 111
    uint public lower;  //777

    function cast() public {
        
        uint256 base  = 11111;
        uint256 based = 77777;
        
        lower = base / 1E2;
        upper = based / 1E2;
    }

}
```




## 8. endVaults and updateAllVaultsAndAccounts use a different approach compared to other functions

Does not call `_updateUserAccounts`, like the other functions.
Instead, it updates a single distribution then calls `_updateVaultAccount` to update the related vault accounts.

This is because `_updateUserAccounts` gets distribution from storage. So we don't want to loop over each vaultId calling `_updateUserAccounts`, as it would mean redundant storage calls for distribution.
```solidity
            // get corresponding user+vault account for this active distribution 
            DataTypes.Distribution memory distribution_ = distributions[distributionId];
            DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[vaultId][distributionId];
            DataTypes.UserAccount memory userAccount_ = userAccounts[user][vaultId][distributionId];
```
