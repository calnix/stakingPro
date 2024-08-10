# Staking Pro

## Staking assets

- $MOCA tokens
- RP
- MocaNFTs

## Rewards assets

- Staking Power
- $MOCA tokens

## Pool creation

- Only MocaNFT holders can create pools
- 2 NFTs required to create a single pool
- Creation NFTs are essentially locked to created pool
- Creator will have to define the fee structure levied upon rewards earned by pool.
    - fee structure levied upon staking power and $moca can be independent of each other.

    ![Fee structure](image.png)


## Pool characteristics

- Pools have no expiry date unless the pool creator decides to deactivate the pool.
- All participants in the pool ($MOCA stakers, Moca NFT Stakers, RP committers, Pool Creator) will earn both Staking Power and $MOCA token rewards.
- `No max limit` on RP or $MOCA staked.
- `Max 10 NFTs` can be staked into a pool.
- $MOCA tokens and MocaNFTs (except for the 2 NFTs used to create pool) can be staked and unstaked from a pool any time.

### Note on RP

- Users have to delegate a minimum of 50 RP per pool per stake function call.
- Staked RP cannot be unstaked back to a user's balance; it can only be shuffled about between pools.
- Users can transfer any amount of RP from pool to pool, at any time.

> Note: users will pay gas for all on-chain RP related transactions using their Realm Wallet    

## Pool deactivation

- Pool can be deactivated by the owner.
- Pool will enter a 14-day cooldown period.
- During cooldown, pool will continue to earn rewards as per normal. However, there can be no inflow of assets.
  - this is to facilitate users early warning notice to move their assets to another pool, avoiding disruption.
- After cooldown, the pool creator can unstake the 2 NFTs used to create the pool.
  - No further staking is possible.
  - No reactivation is possible.

## Rewards Emitted

Two types:

1. Staking Power
2. $Moca Tokens

Rewards are distributed on a relative basis. Pools compete against each other for a slice of a constant global emission rate of either rewards type.

### Rewards emissions calculation

**Staking Power Rewards**

- Based on RP
- Higher the RP delegated to a pool relative to other pools, higher the Staking Power pool participants will receive

**$MOCA Token Rewards**

- Based on `$MOCA tokens` staked
- The greater the $MOCA tokens staked to a pool, relative to other pools, the greater the amount of $MOCA tokens as rewards the pool would receive.

### Rewards boosters

**Moca NFTS**

- Moca NFTs staked will act as a boost to both types of rewards for a pool
- The creation NFTs do not contribute to the boosting effect - only NFTs staked after.

**$Moca Tokens**

- `$MOCA tokens` staked will act as a boost on the Staking Power Rewards
- I.e., tokens staked will contribute towards the calculation of token rewards, as well as serving as a booster upon staking power rewards.

**RP delegated**

- RP delegated only contributes towards boosting staking power

## Rewards and Boost calculations

- boost calculations are unknown
- rewards calculations are unknown
- rewards are not auto-compounded

## Fees

Creator of the pool will be able to adjust the rewards structure of both types of rewards (Staking power, $MOCA).

### Fee types

- Pool Creator Rewards: 0% - 100%
- Total NFT Staking Rewards
    - Total commission for NFT holders.
    - If multiple NFTs are staked into a pool, this commission % will be split equally between all NFT holders.
- Total $MOCA Staking Rewards
    - Total commission for $MOCA Stakers. Rewards will be proportionally distributed between all $MOCA stakers
- RP Rewards, %
    - Total commission for users who commit RP. Rewards will be proportionally distributed between all the RP committers depending on their commitment

> Total Fee % across the 4 fee types would naturally add up to be 100%

- Modifiable at any time
- Creator and only adjust to reduce their own fee, in a manner to increase the rewards enjoyed by other pool participants.
- E.g.:
    - Creator reduces their own rewards allocation %, to increases the rewards share % for $MOCA stakers/MocaNFT stakers/RP delegators.
    - Essentially, creators reallocate a portion of their initially described fees, to some other participants.

> Note: Gas fees used during commission adjustment will be paid by the Pool Creator.

## Claiming Rewards

- Staking power is recorded off-chain
- Only MocaTokens can be claimed from the contract
- Users can claim at any time



