# TODO

## 2. endVaults and updateAllVaultsAndAccounts

consider if there is a way to simplify the logic of these functions.

### 2.1 endVaults and updateAllVaultsAndAccounts use a different approach compared to other functions

Does not call `_updateUserAccounts`, like the other functions.
Instead, it updates a single distribution then calls `_updateVaultAccount` to update the related vault accounts.

This is because `_updateUserAccounts` gets distribution from storage. So we don't want to loop over each vaultId calling `_updateUserAccounts`, as it would mean redundant storage calls for distribution.

```solidity
            // get corresponding user+vault account for this active distribution 
            DataTypes.Distribution memory distribution_ = distributions[distributionId];
            DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[vaultId][distributionId];
            DataTypes.UserAccount memory userAccount_ = userAccounts[user][vaultId][distributionId];
```

---

# NftLocker

## 1. add streamingOwnerCheck()

- streaming contract is deployed on ethereum, as will the NftLocker
- streamingOwnerCheck() will check if the msg.sender is the owner of tokenId
- if not, revert with error

```solidity
        IModule(module).streamingOwnerCheck(msg.sender, tokenIds);
```

## 2. use of storage pointers

- use of storage pointers for structs

---

## 8. document: 
        - how rewards are calculated: distribution, vault, user


# Super nice to have: likely too much added complexity

## 1. After pausing the contract to update nft multiplier, can i put a lock on calculations for distribution, vault, user?

- can update nft multiplier without affecting the calculations for distribution, vault, user
- there won't be drift between batchs of update vaults and boosted values.