# Random thoughts

## 1. 

should we prevent vaults from being created if there are no active distributions?
i.e. do a length check on the distributions array, and if it's 0, revert?

## 2. pool address in nft_registry

nftRegistry will be deployed before pool.
pool will require nftRegistry address in constructor
therefore, nftRegistry cannot take in pool address as constructor.

## 3. can i expressed rp in integer values?

- will it round to 0, if so where?

## 4. add checkls for assets transfers

## 5. should accounts be updated on creation? how are they to be updated before 1st stake?

On first stake, all user indexes are updated to match vault indexes:
- _updateUserAccount() always updates userIndexes(all 3), to vault's latest
- this starts a user off at 0 prior accrued rewards for that vault

If a user has nothing staked to a vault, its userAccounts for that vault should be zero-ed out.
- none of its indexes should be updated
- so if a userAccount should be 0-ed out; txn should revert before
-e.g claimRewards() should revert if user has nothing staked to a vault

If a user has at least 1 staking asset staked in a vault,
- all userAccount indexes should be updated to match vault indexes
- even for the one's that user has nothing staked to
- this ensures that the user Account is kept in sync with the vault
