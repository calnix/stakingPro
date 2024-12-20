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


