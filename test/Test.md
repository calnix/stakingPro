# Local distribution: all on same chain

- will not involve EVMVault.sol

[#1]
- setup 3 distributions: stakingPower:0, someToken:1
- setup 2 vaults: vault1, vault2
- 3 users: user1, user2, user3

**Deploy**
- StateSetUpDistribution: staking power
**StartTime**
- StateCreateVault - *user 1 creates vault1*
- StateStakeTokens
- StateStakeNfts
- StateStakeRP
- StateUnstake
**- StateSetUpDistribution: someToken** [*fork: for risk testing*]
- StateUpdateCreationNfts
- StateCreateVault_2 [new creation nfts amount]
- StateMigrateVaults
- StateStakeOnBehalfOf
**- StateClaimRewards**
- setRewardsVault: negative test; cannot claim existing rewards
- **StateUpdateVaultFees**:
    - nftFeeFactor
    - creatorFeeFactor
    - realmPointsFeeFactor
- StateActivateCooldown
- StateEndVaults: end vault1
**- StateUpdateDistribution**
- test updated distribution
- StateUpdateVaultCooldown: end vault2
**- StateEndDistributionImmediately** 
- StateSetRewardsVault: positive test; new distribution setup
**- StateSetEndTime**

## misc fork [Pool Management]
- StateUpdateCreationNfts
- StateUpdateMinimumRealmPoints
- StateSetRewardsVault
- partial deposits for distributions

## Risk testing

import fork into separate file

- pause
- unpause
- freeze
- emergencyExit

## integration testing

- lz: refund
- https://docs.layerzero.network/v2/developers/evm/technical-reference/api#send

X-Chain
- will involve EVMVault.sol

## Migration

- v1 to v2: rewardsVault

## User fns

### user fns

createVault
stakeTokens
stakeNfts
stakeRP
migrateRP
unstake
claimRewards
updateVaultFees
activateCooldown
endVaults

PRIV

stakeOnBehalfOf
setEndTime
setRewardsVault
updateMaximumFeeFactor
updateMinimumRealmPoints
updateCreationNfts
updateVaultCooldown
--------------------
setupDistribution
updateDistribution

### ---

#### Overview 
create 2 distributions - update both
create 2 vaults
    1: user1 creates vault1
    sometime after:
    - user1 stakes half of assets into it
    - user2 stakes half of assets into it
    <new distribution>
    2: user 2 creates vault2; stakes half of assets into it

t = 1 [start]
 user1 create vault1
 user1 stakes half of their tokens+rp into it [no more nfts]

t = 6 [delta: 5]
 user2 stakes half of their tokens+rp+2nfts into it

t = 11 [delta: 5]
 distribution 1 created [starts @ t=21]

t = 16 [delta: 5]
 user1 stakes remaining assets into vault1 [half of tokens+rp]
 user2 stakes remaining assets into vault1 [half of their tokens+rp +2nfts]

t = 21 [delta: 5]
 distribution 1 started
 updateCreationNfts
 *add: check view fns for pending rewards*

t = 26 [delta: 5]
 user2 creates vault2 [5 seconds into distribution 1]
 check pool.CreationNfts
 *stale checks: maybe move to 21, together w/ check view.*

t = 31 [delta: 5]
 user2 migrates half his RP to vault2 [migrateRp]
 *both vaults updated due to migration: check both vaults and vaultAccounts for both distributions*
 
t = 36 [delta: 5]
 user2 unstakes half of his tokens+2nfts from vault1 [unstake]
 *vault1 updated due to unstake: can check vault1 and vaultAccounts for both distributions - maybe can drop due to t30 checks*

t = 41 [delta: 5]
 user2 stakes half of assets to vault2

t = 46 [delta: 5]
 vault1: updateVaultFees by user1
 vault2: updateVaultFees by user2
  [fees are dropped and increased proportionally, net transfer from creator to others]
  [check both vaults accrue rewards from both distributions; assets staked since t46]
 updated:
 - both distributions updated
 - both vault accounts updated
 - user1+vault1 updated
 - user2+vault1 NOT updated
 - user1+vault2 NOT updated
 - user2+vault2 updated

t = 51 [delta: 5]
 [creator fees are dropped entirely; other fees remain unchanged]
 vault1: updateVaultFees by user1
 vault2: updateVaultFees by user2
  - check that rewards are accrued correctly, accounting for recent fee changes
 updated:
 - both distributions updated
 - both vault accounts updated
 - user1+vault1 updated
 - user2+vault1 NOT updated
 - user1+vault2 NOT updated
 - user2+vault2 updated

t = 56 [delta: 5]
 user2 claims rewards from vault1+d1
 user2 claims rewards from vault2+d1 
 user1 cannot claim rewards from vault2+d1 -> nothing staked
 this checks the combo: (user2+vault1), (user1+vault2); which was not checked at t46 or t51
  - check that rewards are accrued correctly, accounting for recent fee changes
 updated:
 - both distributions updated
 - both vault accounts updated
 - user1+vault1 NOT updated
 - user2+vault1 updated
 - user1+vault2 updated
 - user2+vault2 NOT updated

t = 61 [delta: 5]
 vault2: activateCooldown
 updated:
 - both distributions updated
 - vault2 accounts updated
 - user2 accounts updated
 - stale: vault1 accounts, user1 accounts

t = 61+1day [delta: 1 day]
 vault2: endVault

t = 71 [delta: 5]
 - claimRewards after vault ended

t = 76 [delta: 5]
 
t = 81 [delta: 5]
 

---
split timeline fork
1. endDistribution + claimRewards
2. endContract + claimRewards
3. update NFT multiplier
4. updateMaximumFeeFactor
5. updateMinimumRealmPoints
6. emergencyExit

claimRewards [after end contract]
=========== [can i fork?]
stakeOnBehalfOf
updateDistribution
endDistribution
setEndTime