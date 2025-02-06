# Random thoughts

## 1. 

should we prevent vaults from being created if there are no active distributions?
i.e. do a length check on the distributions array, and if it's 0, revert?

## 2. pool address in nft_registry

nftRegistry will be deployed before pool.
pool will require nftRegistry address in constructor
therefore, nftRegistry cannot take in pool address as constructor.