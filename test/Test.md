Local distribution: all on same chain

- will not involve EVMVault.sol

[#1]
- setup 3 distributions: stakingPower:0, someToken:1

- StateDeploy
- StateStartTime
- StateSetUpDistribution: staking power
- StateCreateVault
- StateStakeTokens
- StateStakeNfts
- StateStakeRP
- 
~~- StateClaimRewards~~
- StateSetUpDistribution: someToken
- 


X-Chain
- will involve EVMVault.sol