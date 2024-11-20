# Staking Pro

Chain: Base

## Staking assets

- $MOCA tokens
- MocaNFTs
- RP [off-chain]

**No limits on staking: MOCA, RP, NFTS; at a pool or contract level**

## Rewards assets

- $MOCA tokens
- Staking Power [off-chain]

## Pool creation

- Only MocaNFT holders can create pools
- 5 NFTs required to create a single pool
- Creation NFTs are locked to created pool
- Creation NFTs do not count towards rewards calc. or boosting.
- Creator will have to define the fee structure levied upon rewards earned by pool
    -- a single fee structure applies to both MOCA rewards and Staking Power

## Pool characteristics

- Pools have no expiry date unless the pool creator decides to deactivate the pool.
- All participants in the pool ($MOCA stakers, Moca NFT Stakers, RP committers, Pool Creator) will earn both Staking Power and $MOCA token rewards.
- `No max limit` on RP, $MOCA or NFTs staked.
- All assets (except creation NFTs) can be staked and unstaked from a pool any time. [$MOCA, NFTs, RP]

### Note on RP [ignore pending discussion]

- Users have to delegate a minimum of 50 RP per pool per stake function call.
- Staked RP cannot be unstaked back to a user's balance; it can only be shuffled about between pools.
- Users can transfer any amount of RP from pool to pool, at any time.

> Note: users will pay gas for all on-chain RP related transactions using their Realm Wallet

## Pool deactivation

- Pool can be deactivated by the owner.
- Pool will enter a 7-day cooldown period.

- During cooldown, pool will continue to earn rewards as per normal. However, there can be no inflow of assets.
  - this is to facilitate users early warning notice to move their assets to another pool, avoiding disruption.

- After cooldown, the pool creator can unstake creation NFTs.
  - No further staking is possible.
  - No reactivation is possible.
  - pool no longer earns rewards.

## Rewards Emitted

Two types:

1. Staking Power
2. $Moca Tokens

Rewards are distributed on a relative basis. Pools compete against each other for a slice of a constant global emission rate of either rewards type.

All participants in the pool ($MOCA stakers, Moca NFT Stakers, RP Stakers, Pool Creator) will earn both Staking Power and $MOCA token rewards.

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
- 10% boost per NFT staked - applied to both reward types.

## Rewards and Boost calculations

- 10% per nft, applied on the base. I.e., boosting effects will not stack.
- unclaimed rewards are not auto-compounded; therefore can be ignored as part rewards calculations.

## Fees

Creator of the pool will be able to adjust the fee structure.

There is only a single fee structure for a pool, which applies the same to both types of rewards (Staking power, $MOCA).

After creation, fees can only be modified such that:
    - creator cannot increase their portion of fees.
    - creator can only reduce their own fee, in a manner to increase the rewards enjoyed by other pool participants.

### Fee types

1) Pool Creator Rewards: 0% - 100%

2) Total NFT Staking Rewards
    - Total rewards for all NFT stakers (excluding creation nfts).
    - If multiple NFTs are staked into a pool, rewards will be split between all NFT holders.

3) Total $MOCA Staking Rewards
    - Total rewards for $MOCA Stakers.
    - Rewards will be proportionally distributed between all $MOCA stakers

4) RP Rewards
    - Total rewards for users who commit RP.
    - Rewards will be proportionally distributed between all the RP committers depending on their commitment

> Total Fee % across the 4 fee types would naturally add up to be 100%

**The portion of rewards to $MOCA Stakers cannot fall below a minimum of 50%. This is applicable to both rewards denominated in tokens and RP.**

### Min. Fee portion to MOCA stakers

- set to 50% initially.
- would like to be updatable  

> Note: Gas fees used during commission adjustment will be paid by the Pool Creator.

## Claiming Rewards

- Staking power is recorded off-chain
- Only MocaTokens can be claimed from the contract
- Users can claim at any time

**Claiming fees: 1-click claim all rewards. user to claim everything across the board at once, irrespective of if its nft staking or creator rewards**

## Financing

- partial deposits whenever
- ability to withdraw extra deposits
    - track totalDeposits and TotalRewardsDeposited, so can withdraw/deposit rewards arbitrarily

## Updatable dimensions [!]

1. Creation nfts required

Changing this will only affect new pools.

2. emissionPerSecond [!]

This might be very complicated/not at all possible. will confirm.

3. NFT Staking Boost

+10% Boost per Nft on base Rewards for both Staking Power and Token Rewards.

4. Pool Cooldown Period

Changing this will only affect new pools that are deactivated after the cooldown period has been adjusted

# Others

1. Rewards to be given out in multiple tokens instead of just $MOCA.

We may want to begin distributing rewards in an additional token. This new distribution may begin mid-way.

2. StakeBehalf

- Context: Airdrop MOCA to users outside of Staking Pro in some campaign
- Auto-stake the airdrop allocation of MOCA for the users instead of airdropping directly to their wallets
- Users can unstake later on to claim their airdrop if they wish to

## Nft locker monitoring

- pause on incorrect withdrawal of nft

## Migration

- on Pro release, simple will be deprecated.
- simple staking must be blocked [!]