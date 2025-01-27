# Local distribution: all on same chain

- will not involve EVMVault.sol

[#1]
- setup 3 distributions: stakingPower:0, someToken:1
- setup 2 vaults: vault1, vault2
- 3 users: user1, user2, user3

**Deploy**
- StateSetUpDistribution: staking power
**StartTime**
- StateCreateVault
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
- 

## Risk testing 

import fork into separate file

- pause
- unpause
- freeze 
- emergencyExit

X-Chain
- will involve EVMVault.sol