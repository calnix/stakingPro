# TODO

## 1. Decimal Precision

indexes are denominated in the distribution's precision
rewards calculated and stored in the distribution's precision

At the end of the day, we are paying out different rewards - so adhere to their respective precision.

However, when calculating rewards, in both `_updateUserAccount` and `_updateVaultAccount`, we must convert the decimal precision of `stakedBase` to the distribution's precision.
Since `stakedBase` is denominated in `1E18`, we must convert it to the distribution's precision.

If the distribution's precision is lower than `1E18`, we are rounding down `stakedBase`, and therefore calculated rewards will be lower than they should be.
If the distribution's precision is higher than `1E18`, we are simply adding zeros to `stakedBase`; this does not impact the rewards calculation. **[TODO: check if this is correct]**

```solidity
    uint256 balanceRebased = (user.stakedTokens * distribution.TOKEN_PRECISION) / 1E18;
    uint256 accruedRewards = _calculateRewards(balanceRebased, newUserIndex, userAccount.index, distribution.TOKEN_PRECISION);
                
    // for calc. rewards from index deltas. assumes tt indexes are expressed in the distribution's precision. therefore balance must be rebased to the same precision
    function _calculateRewards(uint256 balanceRebased, uint256 currentIndex, uint256 priorIndex, uint256 PRECISION) internal pure returns (uint256) {
        return (balanceRebased * (currentIndex - priorIndex)) / PRECISION;
    }

```

### 1.1 If the distribution's precision is lower than `1E18`

- Moca Tokens: 1E18 precision
- Reward Tokens: 1E6 precision

When going from 18 dp to 6 dp, we lose 12 dp of precision.

**Example: 1.2345678 MOCA staked**
 
- 1.23456 MOCA rebased to 1e6 precision: `1_234_567_800_000_000_000` -> `1_234_567`
- Precision is reduced by 12 dp; so `800_000_000_000` is lost.

User's rewards are calculated based on the rebased value: `1_234_567`
This is a rounding down of the original value and therefore rewards are slightly lower than they should be.

**This would not pose issues for us as we do not need to worry about paying out more rewards than we have.**

```solidity
    function sec1() public view returns(uint256) {
        
        uint256 inputTokens = 1.2345678 ether;
        uint256 TOKEN_PRECISION = 1e6;

        uint256 stakedMocaRebased = (inputTokens * TOKEN_PRECISION) / 1E18;
        
        return stakedMocaRebased;   // 1_234_567
    }
```

### 1.2 If the distribution's precision is higher than `1E18`

- Moca Tokens: 1E18 precision
- Reward Tokens: 1E21 precision

When going from 18 dp to 21 dp, we add 3 dp to precision.

**Example: 1.2345678 MOCA staked**

1.2345678 MOCA rebased to 1e21 precision: `1_234_567_800_000_000_000` -> `1_234_567_800_000_000_000_000`

- User's rewards are calculated based on the rebased value: `1_234_567_800_000_000_000_000`
- The added zeros do not impact the rewards calculation.

**This would not pose issues for us.**

**CONCLUSION: there are no issues with rebasing the staked MOCA to the distribution's precision, as there is no negative impact on the rewards calculation.**

```solidity
    function sec2() public view returns(uint256) {
        
        uint256 inputTokens = 1.2345678 ether;
        uint256 TOKEN_PRECISION = 1e21;

        uint256 stakedMocaRebased = (inputTokens * TOKEN_PRECISION) / 1E18;
        
        return stakedMocaRebased;   // 1_234_567_800_000_000_000_000
    }
```

### 1.3 What is the lowest precision we can rebase to?

- Reward Tokens: 1E1 precision

```solidity
    function sec3() public view returns(uint256) {
        
        uint256 inputTokens = 1.2345678 ether;
        uint256 TOKEN_PRECISION = 1e1;

        uint256 stakedMocaRebased = (inputTokens * TOKEN_PRECISION) / 1E18;
        
        return stakedMocaRebased;   // 12
    }
``` 

1.2345678 MOCA rebased to 1E1 precision: `1_234_567_800_000_000_000_000` -> `12`

**CONCLUSION: we can rebase to 1E1 precision without issues.**

- Reward Tokens: 1E0 precision

```solidity
    function sec4() public view returns(uint256) {
        
        uint256 inputTokens = 1.2345678 ether;
        uint256 TOKEN_PRECISION = 1e0;

        uint256 stakedMocaRebased = (inputTokens * TOKEN_PRECISION) / 1E18;
        
        return stakedMocaRebased;   // 1
    }
```

1.2345678 MOCA rebased to 1E0 precision: `1_234_567_800_000_000_000_000` -> `1`

**CONCLUSION: we can rebase to 1E0 precision without issues.**

- Reward Tokens: 0 precision

```solidity
    function sec5() public view returns(uint256) {
        
        uint256 inputTokens = 1.2345678 ether;
        uint256 TOKEN_PRECISION = 0;

        uint256 stakedMocaRebased = (inputTokens * TOKEN_PRECISION) / 1E18;
        
        return stakedMocaRebased;   // 0
    }
```

**CANNOT HAVE 0 PRECISION.**

### 1.4 Precision loss for Indexes; in _calculateDistributionIndex

check and test if precision loss is a problem, given varying token precisions:

Scenario 1: reward tokens are denominated in 1e1 precision

```solidity
        function indexPrecision() public pure returns(uint256) {
        
        uint256 totalBalance = 1.23 ether;
        uint256 distribution_TOKEN_PRECISION = 1e1;
        
        // totalBalanceRebased = 12
        uint256 totalBalanceRebased = (totalBalance * distribution_TOKEN_PRECISION) / 1E18;

        //note: indexes are denominated in the distribution's precision
        //assume first update, distribution_index = 0
        uint256 distribution_index = 0;
        
        // assume emissionPerSecond is 1 unit of reward token
        uint256 emittedRewards = (1 * distribution_TOKEN_PRECISION) * 1;      // emittedRewards = distribution.emissionPerSecond * timeDelta: 
        // emittedRewards = 10

        uint256 nextDistributionIndex = ((emittedRewards * distribution_TOKEN_PRECISION) / totalBalanceRebased) + distribution_index; 

        // nextDistributionIndex = 8 = ((10 * 10) / 12) + 0
        return nextDistributionIndex;   
    }  
```

`nextDistributionIndex` = 0.8 units of reward tokens per unit MOCA staked
We intended to distribute 1 reward token per unit MOCA staked. But ended up distributing 0.8 reward tokens per unit MOCA staked.

check if correct:

    - mocaStaked: 1.23e18
    - emittedRewards = 1 unit of reward token, in 1e1 precision [10]

    - mocaStakedRebased: (1.23e18 * 1e1) / 1e18 = 12
    - rewardsPerMocaStakedRebased: (emittedRewards * rewardPrecision) / mocaStakedRebased = (10 * 1e1) / 12 = 8 
    
    0.8 reward tokens are given out per stakedMoca. [since 1 unit is 1e1]
    0.8 * 1.23 = 0.984 reward tokens ought to be emitted in TOTAL 
    slightly lesser than the 1 reward token that was meant to be emitted 

Scenario 2: reward tokens are denominated in 1e21 precision

```solidity
    function indexPrecision2() public pure returns(uint256) {
        
        uint256 totalBalance = 1.23 ether;
        uint256 distribution_TOKEN_PRECISION = 1e21;
        
        // totalBalanceRebased = 1230000000000000000000 = 1.23e21
        uint256 totalBalanceRebased = (totalBalance * distribution_TOKEN_PRECISION) / 1E18;

        //note: indexes are denominated in the distribution's precision
        //assume first update, distribution_index = 0
        uint256 distribution_index = 0;
        
        // assume emissionPerSecond is 1 reward token
        uint256 emittedRewards = (1 * distribution_TOKEN_PRECISION) * 1;      // emittedRewards = distribution.emissionPerSecond * timeDelta: 
        // emittedRewards = 1000000000000000000000 = 1e21

        uint256 nextDistributionIndex = ((emittedRewards * distribution_TOKEN_PRECISION) / totalBalanceRebased) + distribution_index; 
        
        // nextDistributionIndex = 0.813008130081300813008 = ((1e21 * 1e21) / 1.23e21) + 0
        return nextDistributionIndex;   
    }  
```

`nextDistributionIndex` = 0.813008130081300813008 units of reward tokens per unit MOCA staked
We intended to distribute 1 reward token per unit MOCA staked. But ended up distributing 0.813008130081300813008 reward tokens per unit MOCA staked.

check if correct:

    - mocaStaked: 1.23e18
    - emittedRewards = 1 unit of reward token, in 1e21 precision [1e21]

    - mocaStakedRebased: (1.23e18 * 1e21) / 1e18 = 1.23e21
    - rewardsPerMocaStakedRebased: (emittedRewards * rewardPrecision) / mocaStakedRebased = (1e21 * 1e21) / 1.23e21 = 0.813008130081300813008
    
    0.813008130081300813008 reward tokens are given out per stakedMoca. [since 1 unit is 1e21]
    0.813008130081300813008 * 1.23 = 0.99999999999999999999984 reward tokens ought to be emitted in TOTAL 
    slightly lesser than the 1 reward token that was meant to be emitted 

**CONCLUSION: Regardless of the precision of the reward tokens, and its impact on index calculation, the total rewards emitted will be slightly lesser than the intended amount. This is fine.**

There should not be any issues with rewards and index calculations, as long as none of the following variables are zero:

- `timeDelta`
- `distribution.emissionPerSecond`
- `distribution.TOKEN_PRECISION`
- `totalBalance`: which could be either `totalBoostedRealmPoints` or `totalBoostedStakedTokens` [in `_updateDistributionIndex`]
- `boostedBalance`: which could be either `vault.boostedRealmPoints` or `vault.boostedStakedTokens` [in `_updateVaultAccount`]
- `user.stakedTokens`: in `_updateUserAccount`


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
