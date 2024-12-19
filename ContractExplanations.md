
# Contract Walkthrough

## Constructor

```solidity
 constructor(address registry, uint256 startTime_, uint256 nftMultiplier, uint256 creationNftsRequired, uint256 vaultCoolDownDuration,
        address owner, string memory name, string memory version) payable EIP712(name, version) Ownable(owner)
```

On deployment, the following must be defined:

1. address of nft registry contract (should be deployed in advance)
2. startTime: user are only able to call staking functions after startTime.
3. nftMultiplier: boost factor per nft
4. creationNftsRequired: number of creation nfts required per vault
5. vaultCoolDownDuration: cooldown period of vault before ending permanently

## Decimal Precision for feeFactors and NFT multiplier

`PRECISION_BASE` is expressed as `10_000`, for 2dp precision.

PrecisionBase reference:
- integer: 100
- 2 dp   : 10000

On 2dp base:
- 100% : 10_000
- 50%  : 5000
- 1%   : 100
- 0.5% : 50
- 0.25%: 25
- 0.05%: 5
- 0.01%: 1

Therefore for an nft multiplier of 10%, nftMultiplier must be set to `1000`, when `PRECISION_BASE` is expressed as `10_000`.
This applied similarly to fee factors.

# Owner functions

## SetUp Distribution

`setupDistribution(uint256 distributionId, uint256 startTime, uint256 endTime, uint256 emissionPerSecond, uint256 tokenPrecision)`

setUp a new distribution

### Staking power setup

- distributionId: 0
- token precision: 1e18

startTime should be the same as stakingPro. endTime to be left as 0.

staking power will be identified by its distribution id as 0, throughout the contract.


### Token setup

- both start and end times must be defined
- else, we would be emitting token rewards indefinitely
- stakingPro does not check if tokens have been deposited or not; it will only make a call to RewardsVault contract to transfer

## updateDistribution

```solidity
    /** 
     * @notice Updates the parameters of an existing distribution
     * @dev Can modify:
     *      - startTime (only if distribution hasn't started)
     *      - endTime (can extend or shorten, must be >= block.timestamp)
     *      - emission rate (can be modified at any time)
     * @dev At least one parameter must be modified (non-zero)
     * @param distributionId ID of the distribution to update
     * @param newStartTime New start time for the distribution. Must be > block.timestamp if modified
     * @param newEndTime New end time for the distribution. Must be > block.timestamp if modified
     * @param newEmissionPerSecond New emission rate per second. Must be > 0 if modified
     * @custom:throws Errors.InvalidDistributionParameters if all parameters are 0
     * @custom:throws Errors.DistributionEnded if distribution has already ended
     * @custom:throws Errors.DistributionStarted if trying to modify start time after distribution started
     * @custom:throws Errors.InvalidStartTime if new start time is not in the future
     * @custom:throws Errors.InvalidEndTime if new end time is not in the future
     * @custom:throws "Pool is frozen" if pool is in frozen state 
     */

    function updateDistribution(uint256 distributionId, uint256 newStartTime, uint256 newEndTime, uint256 newEmissionPerSecond) external onlyOwner{}
```

- stop distribution: set endTime to block.timestamp
- can shorten/length distribution by modifying startTime and endTime
- change emission per second of a distribution (increase, decrease, cannot make 0)

