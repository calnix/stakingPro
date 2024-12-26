1. createVault

- add batch fn to registry to check ownership of multiple nfts

```solidity
        for (uint256 i; i < CREATION_NFTS_REQUIRED; i++) {

            (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds[i]);   // note: add batch fn to registry to check ownership
            
            if(owner != onBehalfOf) revert Errors.IncorrectNftOwner(tokenIds[i]);
            if(nftVaultId != bytes32(0)) revert Errors.NftAlreadyStaked(tokenIds[i]);
        }
```

2. caching msg.sender as onBehalfOf

```solidity
        address onBehalfOf = msg.sender;
```
consider just using msg.sender directly

3. decide if you want to remove vaultId from the struct


4. add streamingOwnerCheck() to NftLocker

- streaming contract is deployed on ethereum, as will the NftLocker
- streamingOwnerCheck() will check if the msg.sender is the owner of tokenId
- if not, revert with error

```solidity
        IModule(module).streamingOwnerCheck(msg.sender, tokenIds);
```

nft streaming: 0xb46F2634Fcb79fa2F73899487d04acfB0252A457

5. add batch fn to registry to check ownership of multiple nfts

```solidity
        (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds);

        for (uint256 i; i < CREATION_NFTS_REQUIRED; i++) {

            (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds[i]);   // note: add batch fn to registry to check ownership
            
            if(owner != onBehalfOf) revert IncorrectNftOwner(tokenIds[i]);
            if(nftVaultId != bytes32(0)) revert NftAlreadyStaked(tokenIds[i]);
        }
```

6. add batch fn to registry to check if multiple nfts are already staked

```solidity
        (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds);
```

=================================================================================================
`_updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);`

- stakeTokens
- stakeNfts
- stakeRP
- claimRewards
- updateVaultFees
- activateCooldown
- migrateVaults [twice, ]
	`_updateUserAccounts(msg.sender, oldVaultId, oldVault, oldUserVaultAssets);`
	`_updateUserAccounts(msg.sender, newVaultId, newVault, newUserVaultAssets);`


endVault: ?

```solidity 

_updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);
- each looploads distribution, vaultAccount, userAccount from storage
- just loops through _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

_updateUserAccount(userVaultAssets, userAccount_, vault, vaultAccount_, distribution_);


```

7. document: 
        - how rewards are calculated: distribution, vault, user

8. After pausing the contract to update nft multiplier, can i put a lock on calculations for distribution, vault, user?

- can update nft multiplier without affecting the calculations for distribution, vault, user
- there won't be drift between batchs of update vaults and boosted values.


