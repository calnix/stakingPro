1. Handling fee pct values against diff token precision values

2. Calculating NFT Boost factors and updating it on stakeNfts

3. redistribution inactive participants in a vault
    - their rewards go to active participants
    - i.e
    - vault has rp staked, but no moca tokens. Only eligible for staking power; not token rewards
    - staking power earned -> rp stakers get a fee; as per fee schedule
    - what about the component that is meant to go to moca token stakers

4. Minimum of 50 RP for onboarding to contract

5. Special NFTS

----

# Design considerations

1. Decimal Precision

index rebased to 1e18
rewards calculated and stored in native

however,

in _updateVaultAccount::_calculateRewards

_calculateRewards
- uses delta in index to calculate rewards accrued to vault
- (balance * (currentIndex - priorIndex)) / 1E18;

At the end of the day, we are paying out in native precision,
so, standardize to that.

to standardize to the rewards token's precision, 
we must convert the decimal precision of stakedBase

this impacts _calculateDistributionIndex and _calculateRewards

staking base gets rounded down: 
```solidity

contract PrecisionConversion {

    uint public upper;  // 111
    uint public lower;  //777

    function cast() public {
        
        uint256 base  = 11111;
        uint256 based = 77777;
        
        lower = base / 1E2;
        upper = based / 1E2;
    }

}
```

2. Decimal Precision for feeFactors and NFT multiplier [PRECISION_BASE]

integer: 100
2 dp   : 10000

on 2dp base
- 100% : 10_000
- 50%  : 5000
- 1%   : 100
- 0.5% : 50
- 0.25%: 25
- 0.05%: 5
- 0.01%: 1