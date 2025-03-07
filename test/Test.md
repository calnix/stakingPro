# Local distribution: all on same chain

- will not involve EVMVault.sol

[#1]
- setup 3 distributions: stakingPower:0, someToken:1
- setup 2 vaults: vault1, vault2
- 3 users: user1, user2, user3


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
 distribution 1 created [starts @ t=21]aaaaaaaaaaa

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
 vault2: endVaults
 updated:
 - both distributions updated
 - vault2 accounts for all distributions updated
 - stale: vault1 accounts, all user accounts

t = 66+1day [delta: 5]
 transition: user2 unstakes from vault2
 - unstake after vault ended: make sure its vault assets are decremented
 - claimRewards after vault ended: make sure its not earning

t = 86471 [delta: 5]
 `setEndTime`
    - use main timeline
    - transition fn checks setEndTime
    - on transition, check other fns's endTime checks
    - check claimRewards

---
## Pool Management fns: split timeline fork

`stakeOnBehalfOf`
- split on vault2 creation
- user2 restakes nfts and migrates RP to vault2
- user2 unstakes from tokens from vault1; but does not restake tokens
- instead OPERATOR restakes on behalf of user2
- vault2 checks and user2 accounts should tally as per main timeline's values

`updateActiveDistributions`
- split at T16. [D1 created at T11]
- update active distributions and check new limit

# `updateMaximumFeeFactor` [!!!]
- split on T46; both users update fees on both vaults
- T46: both users update fees on both vaults
- T51: user1 updates fees on vault1; user2 updates fees on vault2

maximumFeeFactor determines how much of the rewards are taken as fees.
totalFeeFactor cannot exceed maximumFeeFactor.
if maximumFeeFactor is lowered: amount of rewards taken as fees is lowered.
if maximumFeeFactor is raised: amount of rewards taken as fees is increased.
- creatorFeeFactor can only be lowered;

`updateMinimumRealmPoints`
- t1: user1 staked half their rp
- t6: user2 staked half their rp
 transition fn on T1: updateMinimumRealmPoints
 split on T6: user2 stakes lower amount of rp

`updateCreationNfts`
- transition fn: T16
- state tested on T21

`updateVaultCooldown`
- split before activateCooldown is called on vault2
- run is parallel to main timeline, when vault2 can end in 5 seconds
- transition fn: T56 - test `updateVaultCooldown`
- split test on T61: activateCooldown w/ new cooldown period [copy T61 tests]

# `updateDistribution`[!!!]
- split sometime after distribution 1 is created
- might need a couple of parallels to test different scenarios
startTime, endTime, emissionPerSecond
- increase/decrease all vars
- combo checks: increase/decrease in totalRequired: {not started, midway}
- test endDistribution error: `if(distribution.manuallyEnded == 1) revert Errors.DistributionManuallyEnded();`

`endDistribution`
- split at T46
- end D1 then warp to T46: check that rewards are only accrued till T41, nothing further
- check claimRewards
`setRewardsVault`
- continue on the same split

## update NFT multiplier process

- PoolT46p_MaintenanceMode.t.sol

## Risk fns

emergencyExit

## others 

- partial deposits for distributions
