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
 user2 stakes half of assets into it

t = 11 [delta: 5]
 distribution 1 created

t = 16 [delta: 5]
 user1 stakes half of assets into it
 user2 stakes half of assets into it

t = 21 [delta: 5]
 distribution 1 created & started
 updateCreationNfts

t = 26 [delta: 5]
 user2 creates vault2 [5 seconds into distribution 1]
 user2 migrates half of assets to vault2 [migrateRp,unstake]
 user3 stakes half of assets to vault2

t = 31 [delta: 5]
 vault2: updateMaximumFeeFactor

t = 36 [delta: 5]
 vault1: activateCooldown

t = 41 [delta: 5]
 vault1: endVaults

t = 46 [delta: 5]
 updateVaultCooldown

t = 51 [delta: 5]
 vault2: activateCooldown

t = 56 [delta: 5]

---
split timeline fork
1. endDistribution + claimRewards
2. endContract + claimRewards
3. update NFT multiplier
4. updateMinimumRealmPoints
5. emergencyExit

claimRewards [after end contract]
=========== [can i fork?]
stakeOnBehalfOf
updateDistribution
endDistribution
setEndTime