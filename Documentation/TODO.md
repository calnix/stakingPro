# TODO

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
    uint256 accruedRewards = _calculateRewards(balanceRebased, newUserIndex, userAccount.index, distribution.TOKEN_PRECISION);
                
    // for calc. rewards from index deltas. assumes tt indexes are expressed in the distribution's precision. therefore balance must be rebased to the same precision
    function _calculateRewards(uint256 balanceRebased, uint256 currentIndex, uint256 priorIndex, uint256 PRECISION) internal pure returns (uint256) {
        return (balanceRebased * (currentIndex - priorIndex)) / PRECISION;
    }

```

### 1.1 Staking base gets rounded down:

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

### 1.2 Precision loss in _calculateDistributionIndex

- check and test if precision loss is a problem, given varying token precisions

```solidity
    // Precision handling for balance conversion
    uint256 totalBalanceRebased = (totalBalance * distribution.TOKEN_PRECISION) / 1E18;
    if (totalBalanceRebased == 0) revert PrecisionLoss();
```

## 2. Errors to be a library containing all errors

## 3. endVaults and updateAllVaultsAndAccounts

consider if there is a way to simplify the logic of these functions.

### 3.1 endVaults and updateAllVaultsAndAccounts use a different approach compared to other functions

Does not call `_updateUserAccounts`, like the other functions.
Instead, it updates a single distribution then calls `_updateVaultAccount` to update the related vault accounts.

This is because `_updateUserAccounts` gets distribution from storage. So we don't want to loop over each vaultId calling `_updateUserAccounts`, as it would mean redundant storage calls for distribution.
```solidity
            // get corresponding user+vault account for this active distribution 
            DataTypes.Distribution memory distribution_ = distributions[distributionId];
            DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[vaultId][distributionId];
            DataTypes.UserAccount memory userAccount_ = userAccounts[user][vaultId][distributionId];
```

## 4. caching msg.sender as onBehalfOf

```solidity
        address onBehalfOf = msg.sender;
```
consider just using msg.sender directly

## 5. createVault: add batch fn to registry to check ownership of multiple nfts

- add batch fn to NFT_REGISTRY to check ownership of multiple nfts

```solidity
        for (uint256 i; i < CREATION_NFTS_REQUIRED; i++) {

            (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds[i]);   // note: add batch fn to registry to check ownership
            
            if(owner != onBehalfOf) revert Errors.IncorrectNftOwner(tokenIds[i]);
            if(nftVaultId != bytes32(0)) revert Errors.NftAlreadyStaked(tokenIds[i]);
        }
```

## 6. stakeNFts: add batch fn to registry to check if multiple nfts are already staked

```solidity
        (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds);
```

## 7. add streamingOwnerCheck() to NftLocker

- streaming contract is deployed on ethereum, as will the NftLocker
- streamingOwnerCheck() will check if the msg.sender is the owner of tokenId
- if not, revert with error

```solidity
        IModule(module).streamingOwnerCheck(msg.sender, tokenIds);
```

nft streaming: 0xb46F2634Fcb79fa2F73899487d04acfB0252A457

## 8. document: 
        - how rewards are calculated: distribution, vault, user


# Super nice to have: likely too much added complexity

## 1. After pausing the contract to update nft multiplier, can i put a lock on calculations for distribution, vault, user?

- can update nft multiplier without affecting the calculations for distribution, vault, user
- there won't be drift between batchs of update vaults and boosted values.

## 2. Special NFTS
