# Design considerations

## 1. endVaults and updateAllVaultsAndAccounts use a different approach compared to other functions

Does not call `_updateUserAccounts`, like the other functions.
Instead, it updates a single distribution then calls `_updateVaultAccount` to update the related vault accounts.

This is because `_updateUserAccounts` gets distribution from storage. So we don't want to loop over each vaultId calling `_updateUserAccounts`, as it would mean redundant storage calls for distribution.
```solidity
            // get corresponding user+vault account for this active distribution 
            DataTypes.Distribution memory distribution_ = distributions[distributionId];
            DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[vaultId][distributionId];
            DataTypes.UserAccount memory userAccount_ = userAccounts[user][vaultId][distributionId];
```

## 2. StakeRP and Signature verification

Has to be spun off into a separate contract; since the monolithic contract is already too big.
Was above the contract size limit (26917 > 24576).

Even setting the Optimizer to 1, the contract size was still above the limit.

Experimented with compacting variables in structs. But that didn't work out.

Example, Vault struct:

- startTime, endTime to uint40 and removed to uint8; added casting to code
- this increased contract size. likely cos of the down-casting

That left 2 options;
1. Spin off Signature and RP into a separate contract
2. Move staking calculation logics into a separate linked library contract [external fns]

Going with option 2, meant that the monolithic contract would call external functions in the linked library contract via `delegatecall`.
This would cost more gas, but would reduce contract size.

So when with option 1.
