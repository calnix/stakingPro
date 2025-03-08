# Random thoughts

## 4. add checks for assets transfers


## 8. why does this not work with updateVaultFees?

- the use of _updateVaultFees instead of claimRewards

## 2. pool address in nft_registry

nftRegistry will be deployed before pool.
pool will require nftRegistry address in constructor
therefore, nftRegistry cannot take in pool address as constructor.

## 1. 

should we prevent vaults from being created if there are no active distributions?
i.e. do a length check on the distributions array, and if it's 0, revert?


# Add notes

## 1. should accounts be updated on creation? how are they to be updated before 1st stake?

On first stake, all user indexes are updated to match vault indexes:
- _updateUserAccount() always updates userIndexes(all 3), to vault's latest
- this starts a user off at 0 prior accrued rewards for that vault

If a user has nothing staked to a vault, its userAccounts for that vault should be zero-ed out.
- none of its indexes should be updated; keep it zero-ed out
- so if a userAccount should be 0-ed out; txn should revert before
- e.g claimRewards() should revert if user has nothing staked to a vault

If a user has at least 1 staking asset staked in a vault,
- all userAccount indexes should be updated to match vault indexes
- even for the one's that user has nothing staked to
- this ensures that the user Account is kept in sync with the vault

## 2. ending distributions and last update

distributions that have ended are demarked by `distribution.lastUpdateTimeStamp == distribution.endTime`

```solidity
        if(isPaused) return distribution;
        
        if(block.timestamp < distribution.startTime) return distribution;

        // ..... Distribution has ended: does not apply to distributionId == 0 .....
        if (distribution.endTime > 0 && block.timestamp >= distribution.endTime) {
                if (distribution.lastUpdateTimeStamp <= distribution.endTime) {...}
        }
```

Problem:
- `if (distribution.lastUpdateTimeStamp <= distribution.endTime) {...}` will allow ended distributions to cycle through the final update sequence.


So back to original w/ a add check:

```solidity        
        if(isPaused) return distribution;

        // distribution has ended, and final update done
        if(distribution.lastUpdateTimeStamp == distribution.endTime) return distribution;

        if(block.timestamp < distribution.startTime) return distribution;

        // ..... Distribution has ended: does not apply to distributionId == 0 .....
        if (distribution.endTime > 0 && block.timestamp >= distribution.endTime) {
                if (distribution.lastUpdateTimeStamp < distribution.endTime) {...}
        }
```

- `if (distribution.lastUpdateTimeStamp < distribution.endTime) {...}` will prevent ended distributions from cycling through the final update sequence.
- additionally, `if(distribution.lastUpdateTimeStamp == distribution.endTime) return distribution;` will prevent ended distributions from being updated again.

for `endDistribution()`:

- distribution is updated to latest [lastUpdateTimeStamp == block.timestamp]
- then endTime is set to block.timestamp
- popped from activeDistribution array

> if this distribution is submitted to claimRewards() after it has been ended, it will not go into final update.
> it will return early because `if(distribution.lastUpdateTimeStamp == distribution.endTime) return distribution;`

```
T41: stakeTokens [distribution.lastUpdateTimeStamp == distribution.endTime]
T41: endDistribution -> will not go into final update
```