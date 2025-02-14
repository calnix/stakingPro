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

## 4. test LZ refund mechanism

- https://docs.layerzero.network/v2/developers/evm/technical-reference/api#send