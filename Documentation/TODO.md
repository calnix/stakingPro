# TODO

## 1. endVaults and updateAllVaultsAndAccounts

consider if there is a way to simplify the logic of these functions.

### 1.1 endVaults and updateAllVaultsAndAccounts use a different approach compared to other functions

Does not call `_updateUserAccounts`, like the other functions.
Instead, it updates a single distribution then calls `_updateVaultAccount` to update the related vault accounts.

This is because `_updateUserAccounts` gets distribution from storage. So we don't want to loop over each vaultId calling `_updateUserAccounts`, as it would mean redundant storage calls for distribution.

```solidity
            // get corresponding user+vault account for this active distribution 
            DataTypes.Distribution memory distribution_ = distributions[distributionId];
            DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[vaultId][distributionId];
            DataTypes.UserAccount memory userAccount_ = userAccounts[user][vaultId][distributionId];
```

## 2. Write a section on cross-contract calls

- cover all cross-contract calls in the staking pro
- consider when they may revert or fail, due to states: paused, endTime, etc.

---

# NftLocker

## 1. test new functions

---


# STAKING PRO MISC

1. NFT_Multiplier vs NFT_BOOST_FACTOR: naming
2. RP can be uint128; struct packing
3. struct packing for fees, as input params: createVault + updateVaultFees
4. pack library return variables into struct: gas savings?
5. check internal fns in library, make sure no extra inputs/mappings/outputs
6. Passing _concatArrays from library to stakingPro via function selector:
        https://ethereum.stackexchange.com/questions/3342/pass-a-function-as-a-parameter-in-solidity

Check dups in errors,events and remove.