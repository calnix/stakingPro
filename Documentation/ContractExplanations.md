
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

## updateNftMultiplier [!!!]

When all the vaults have been updated to use the latest `NFT_MULTIPLIER` value, `totalBoostedStakedTokens` and `totalBoostedRealmPoints` should match up.
This serves as a sanity check to ensure that the multiplier is updated correctly, as well as the vaults are updated correctly.

Process:

1. pause contract
2. close all the books: distributions, vaultAccounts [updateAllVaultsAndAccounts]
3. update Nft Multiplier [updateNftMultiplier]
4. totalBoosted values and vault boosted values are now different: update all vault and user Structs. [updateBoostedBalances]
5. unpause

## updateCreationNfts

- Updates the minimum number of NFTs required to create new vaults.
- Owner can set this to 0 to allow vault creation without NFT requirements, or increase/decrease it to adjust the barrier to entry. 
- Existing vaults are unaffected by this change.

## updateMinimumRealmPoints

- Updates the minimum number of Realm Points required to call `stakeRP`.
- Owner can increase/decrease it to adjust the barrier to entry.
- Existing vaults are unaffected by this change.

> stakeRP is how users onboard to the contract.

## updateVaultCooldown

- Updates the cooldown duration for vaults, by changing the global variable `VAULT_COOLDOWN_DURATION`.
- Owner can set this to 0 to allow vaults to be ended immediately, or increase/decrease it to adjust the cooldown period.
- When vault owners call `endVaults`, the global variable `VAULT_COOLDOWN_DURATION` is referenced to determine the cooldown period.

## setupDistribution

`setupDistribution(uint256 distributionId, uint256 startTime, uint256 endTime, uint256 emissionPerSecond, uint256 tokenPrecision)`

Creates a new distribution with specified parameters:
- distributionId: Unique identifier for the distribution
- startTime: When distribution begins emitting rewards
- endTime: When distribution stops emitting rewards
- emissionPerSecond: Rate of reward token emissions
- tokenPrecision: Decimal precision of the reward token (e.g. 1e18)

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

`updateDistribution(uint256 distributionId, uint256 newStartTime, uint256 newEndTime, uint256 newEmissionPerSecond)`

Allows owner to modify parameters of an existing distribution:

- distributionId: ID of the distribution to update
- newStartTime: Can only be modified if distribution hasn't started yet. Must be in the future.
- newEndTime: Can be extended or shortened, but must be after current timestamp
- newEmissionPerSecond: Can be modified at any time to adjust reward rate

Key constraints:
- At least one parameter must be modified (non-zero)
- Cannot modify start time after distribution has begun
- New end time must be after start time
- Cannot set emission rate to 0
- Cannot modify ended distributions

This function enables flexible management of reward distributions by allowing adjustments to timing and emission rates while maintaining key invariants.

```solidity
    /** 
     * @notice Updates the parameters of an existing distribution
     * @dev Can modify:
     *      - startTime (only if distribution hasn't started)
     *      - endTime (can extend or shorten, must be > block.timestamp)
     *      - emission rate (can be modified at any time)
     * @dev At least one parameter must be modified (non-zero)
     * @param distributionId ID of the distribution to update
     * @param newStartTime New start time for the distribution. Must be > block.timestamp if modified
     * @param newEndTime New end time for the distribution. Must be > block.timestamp if modified
     * @param newEmissionPerSecond New emission rate per second. Must be > 0 if modified
     * @custom:throws InvalidDistributionParameters if all parameters are 0
     * @custom:throws NonExistentDistribution if distribution doesn't exist
     * @custom:throws DistributionEnded if distribution has already ended
     * @custom:throws DistributionStarted if trying to modify start time after distribution started
     * @custom:throws InvalidStartTime if new start time is not in the future
     * @custom:throws InvalidEndTime if new end time is not in the future
     * @custom:throws InvalidDistributionEndTime if new end time is not after start time
     * @custom:emits DistributionUpdated when distribution parameters are modified
     */

    function updateDistribution(uint256 distributionId, uint256 newStartTime, uint256 newEndTime, uint256 newEmissionPerSecond) external onlyOwner{}
```

## endDistributionImmediately

`endDistributionImmediately(uint256 distributionId)`

Allows owner to immediately terminate an active distribution:

- distributionId: ID of the distribution to end

This function enables emergency termination of a distribution by setting its end time to the current block timestamp. This effectively stops any further rewards from being distributed while preserving all rewards earned up to that point.
Distribution must exist and be active (not ended).

This provides an emergency control mechanism to halt reward distributions if needed, while ensuring already-earned rewards remain claimable.

## setRewardsVault

`setRewardsVault(address newRewardsVault)`

Allows owner to update the rewards vault contract address:

- newRewardsVault: Address of the new rewards vault contract

This function enables upgrading the rewards vault implementation by pointing to a new contract address. The rewards vault is responsible for holding and distributing rewards tokens.

Key aspects:
- Only callable by owner
- New address must be non-zero
- Allows deploying enhanced rewards vault contracts without modifying StakingPro
- Preserves all staked assets and earned rewards
- Takes effect immediately for future reward distributions

This provides flexibility to upgrade reward distribution logic while maintaining core staking functionality.

## 