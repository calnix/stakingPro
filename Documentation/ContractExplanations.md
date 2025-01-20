# Decimal Precision wrt to reward tokens: rebasing MOCA tokens, rewards, index and emission calculations

Handling varying decimal precision for reward tokens, and ensuring that the index and emission calculations are correct.

## 1. Decimal Precision for indexes and rewards

indexes are denominated in the distribution's precision
rewards calculated and stored in the distribution's precision

At the end of the day, we are paying out different rewards - so adhere to their respective precision.

However, when calculating rewards, in both `_updateUserAccount` and `_updateVaultAccount`, we must convert the decimal precision of `stakedBase` to the distribution's precision.
Since `stakedBase` is denominated in `1E18`, we must convert it to the distribution's precision.

If the distribution's precision is lower than `1E18`, we are rounding down `stakedBase`, and therefore calculated rewards will be lower than they should be.
If the distribution's precision is higher than `1E18`, we are simply adding zeros to `stakedBase`; this does not impact the rewards calculation. **[TODO: check if this is correct]**

```solidity
    uint256 balanceRebased = (user.stakedTokens * distribution.TOKEN_PRECISION) / 1E18;
    uint256 accruedRewards = _calculateRewards(balanceRebased, newUserIndex, userAccount.index, distribution.TOKEN_PRECISION);
                
    // for calc. rewards from index deltas. assumes tt indexes are expressed in the distribution's precision. therefore balance must be rebased to the same precision
    function _calculateRewards(uint256 balanceRebased, uint256 currentIndex, uint256 priorIndex, uint256 PRECISION) internal pure returns (uint256) {
        return (balanceRebased * (currentIndex - priorIndex)) / PRECISION;
    }

```

### 1.1 If the distribution's precision is lower than `1E18`

- Moca Tokens: 1E18 precision
- Reward Tokens: 1E6 precision

When going from 18 dp to 6 dp, we lose 12 dp of precision.

**Example: 1.2345678 MOCA staked**
 
- 1.23456 MOCA rebased to 1e6 precision: `1_234_567_800_000_000_000` -> `1_234_567`
- Precision is reduced by 12 dp; so `800_000_000_000` is lost.

User's rewards are calculated based on the rebased value: `1_234_567`
This is a rounding down of the original value and therefore rewards are slightly lower than they should be.

**This would not pose issues for us as we do not need to worry about paying out more rewards than we have.**

```solidity
    function sec1() public view returns(uint256) {
        
        uint256 inputTokens = 1.2345678 ether;
        uint256 TOKEN_PRECISION = 1e6;

        uint256 stakedMocaRebased = (inputTokens * TOKEN_PRECISION) / 1E18;
        
        return stakedMocaRebased;   // 1_234_567
    }
```

### 1.2 If the distribution's precision is higher than `1E18`

- Moca Tokens: 1E18 precision
- Reward Tokens: 1E21 precision

When going from 18 dp to 21 dp, we add 3 dp to precision.

**Example: 1.2345678 MOCA staked**

1.2345678 MOCA rebased to 1e21 precision: `1_234_567_800_000_000_000` -> `1_234_567_800_000_000_000_000`

- User's rewards are calculated based on the rebased value: `1_234_567_800_000_000_000_000`
- The added zeros do not impact the rewards calculation.

**This would not pose issues for us.**

**CONCLUSION: there are no issues with rebasing the staked MOCA to the distribution's precision, as there is no negative impact on the rewards calculation.**

```solidity
    function sec2() public view returns(uint256) {
        
        uint256 inputTokens = 1.2345678 ether;
        uint256 TOKEN_PRECISION = 1e21;

        uint256 stakedMocaRebased = (inputTokens * TOKEN_PRECISION) / 1E18;
        
        return stakedMocaRebased;   // 1_234_567_800_000_000_000_000
    }
```

### 1.3 What is the lowest precision we can rebase to?

- Reward Tokens: 1E1 precision

```solidity
    function sec3() public view returns(uint256) {
        
        uint256 inputTokens = 1.2345678 ether;
        uint256 TOKEN_PRECISION = 1e1;

        uint256 stakedMocaRebased = (inputTokens * TOKEN_PRECISION) / 1E18;
        
        return stakedMocaRebased;   // 12
    }
``` 

1.2345678 MOCA rebased to 1E1 precision: `1_234_567_800_000_000_000_000` -> `12`

**CONCLUSION: we can rebase to 1E1 precision without issues.**

- Reward Tokens: 1E0 precision

```solidity
    function sec4() public view returns(uint256) {
        
        uint256 inputTokens = 1.2345678 ether;
        uint256 TOKEN_PRECISION = 1e0;

        uint256 stakedMocaRebased = (inputTokens * TOKEN_PRECISION) / 1E18;
        
        return stakedMocaRebased;   // 1
    }
```

1.2345678 MOCA rebased to 1E0 precision: `1_234_567_800_000_000_000_000` -> `1`

**CONCLUSION: we can rebase to 1E0 precision without issues.**

- Reward Tokens: 0 precision

```solidity
    function sec5() public view returns(uint256) {
        
        uint256 inputTokens = 1.2345678 ether;
        uint256 TOKEN_PRECISION = 0;

        uint256 stakedMocaRebased = (inputTokens * TOKEN_PRECISION) / 1E18;
        
        return stakedMocaRebased;   // 0
    }
```

**CANNOT HAVE 0 PRECISION.**

### 1.4 Precision loss for Indexes; in _calculateDistributionIndex

check and test if precision loss is a problem, given varying token precisions:

Scenario 1: reward tokens are denominated in 1e1 precision

```solidity
        function indexPrecision() public pure returns(uint256) {
        
        uint256 totalBalance = 1.23 ether;
        uint256 distribution_TOKEN_PRECISION = 1e1;
        
        // totalBalanceRebased = 12
        uint256 totalBalanceRebased = (totalBalance * distribution_TOKEN_PRECISION) / 1E18;

        //note: indexes are denominated in the distribution's precision
        //assume first update, distribution_index = 0
        uint256 distribution_index = 0;
        
        // assume emissionPerSecond is 1 unit of reward token
        uint256 emittedRewards = (1 * distribution_TOKEN_PRECISION) * 1;      // emittedRewards = distribution.emissionPerSecond * timeDelta: 
        // emittedRewards = 10

        uint256 nextDistributionIndex = ((emittedRewards * distribution_TOKEN_PRECISION) / totalBalanceRebased) + distribution_index; 

        // nextDistributionIndex = 8 = ((10 * 10) / 12) + 0
        return nextDistributionIndex;   
    }  
```

`nextDistributionIndex` = 0.8 units of reward tokens per unit MOCA staked
We intended to distribute 1 reward token per unit MOCA staked. But ended up distributing 0.8 reward tokens per unit MOCA staked.

check if correct:

    - mocaStaked: 1.23e18
    - emittedRewards = 1 unit of reward token, in 1e1 precision [10]

    - mocaStakedRebased: (1.23e18 * 1e1) / 1e18 = 12
    - rewardsPerMocaStakedRebased: (emittedRewards * rewardPrecision) / mocaStakedRebased = (10 * 1e1) / 12 = 8 
    
    0.8 reward tokens are given out per stakedMoca. [since 1 unit is 1e1]
    0.8 * 1.23 = 0.984 reward tokens ought to be emitted in TOTAL 
    slightly lesser than the 1 reward token that was meant to be emitted 

Scenario 2: reward tokens are denominated in 1e21 precision

```solidity
    function indexPrecision2() public pure returns(uint256) {
        
        uint256 totalBalance = 1.23 ether;
        uint256 distribution_TOKEN_PRECISION = 1e21;
        
        // totalBalanceRebased = 1230000000000000000000 = 1.23e21
        uint256 totalBalanceRebased = (totalBalance * distribution_TOKEN_PRECISION) / 1E18;

        //note: indexes are denominated in the distribution's precision
        //assume first update, distribution_index = 0
        uint256 distribution_index = 0;
        
        // assume emissionPerSecond is 1 reward token
        uint256 emittedRewards = (1 * distribution_TOKEN_PRECISION) * 1;      // emittedRewards = distribution.emissionPerSecond * timeDelta: 
        // emittedRewards = 1000000000000000000000 = 1e21

        uint256 nextDistributionIndex = ((emittedRewards * distribution_TOKEN_PRECISION) / totalBalanceRebased) + distribution_index; 
        
        // nextDistributionIndex = 0.813008130081300813008 = ((1e21 * 1e21) / 1.23e21) + 0
        return nextDistributionIndex;   
    }  
```

`nextDistributionIndex` = 0.813008130081300813008 units of reward tokens per unit MOCA staked
We intended to distribute 1 reward token per unit MOCA staked. But ended up distributing 0.813008130081300813008 reward tokens per unit MOCA staked.

check if correct:

    - mocaStaked: 1.23e18
    - emittedRewards = 1 unit of reward token, in 1e21 precision [1e21]

    - mocaStakedRebased: (1.23e18 * 1e21) / 1e18 = 1.23e21
    - rewardsPerMocaStakedRebased: (emittedRewards * rewardPrecision) / mocaStakedRebased = (1e21 * 1e21) / 1.23e21 = 0.813008130081300813008
    
    0.813008130081300813008 reward tokens are given out per stakedMoca. [since 1 unit is 1e21]
    0.813008130081300813008 * 1.23 = 0.99999999999999999999984 reward tokens ought to be emitted in TOTAL 
    slightly lesser than the 1 reward token that was meant to be emitted 

**CONCLUSION: Regardless of the precision of the reward tokens, and its impact on index calculation, the total rewards emitted will be slightly lesser than the intended amount. This is fine.**

There should not be any issues with rewards and index calculations, as long as none of the following variables are zero:

- `timeDelta`
- `distribution.emissionPerSecond`
- `distribution.TOKEN_PRECISION`
- `totalBalance`: which could be either `totalBoostedRealmPoints` or `totalBoostedStakedTokens` [in `_updateDistributionIndex`]
- `boostedBalance`: which could be either `vault.boostedRealmPoints` or `vault.boostedStakedTokens` [in `_updateVaultAccount`]
- `user.stakedTokens`: in `_updateUserAccount`

## 2. Decimal Precision for feeFactors and NFT multiplier

`PRECISION_BASE` is expressed as `10_000`, for 2dp precision.

This applies to fee factors and NFT multiplier.

`PRECISION_BASE` is set to `10_000`.
This is used to express fee factors and NFT multiplier in 2dp precision (XX.yy%).

**On 2dp a base:**
- 100% : 10_000
- 50%  : 5000
- 1%   : 100
- 0.5% : 50
- 0.25%: 25
- 0.05%: 5
- 0.01%: 1

### 2.1 NFT Multiplier

Therefore for an nft multiplier of 10%, `NFT_MULTIPLIER` must be set to `1000`, when `PRECISION_BASE` is expressed as `10_000`.
Increasing `NFT_MULTIPLIER` beyond `10_000` changes the boost from fractional to whole number (e.g., `20_000` = 200% boost).

```solidity
        // calc. boostedStakedTokens
        uint256 incomingBoostedStakedTokens = (amount * vault.totalBoostFactor) / PRECISION_BASE;
```

Example:

```solidity
    function ret() external pure returns(uint256) {
        
        uint256 PRECISION_BASE = 10_000;
        
        uint256 vaultTotalBoostFactor = PRECISION_BASE; //init at 100%  

        uint256 NFT_MULTIPLIER = 1000;                     // 10% = 1000/10_000 = 1000/PRECISION_BASE 
        vaultTotalBoostFactor = vaultTotalBoostFactor + (1 * NFT_MULTIPLIER);   // 10_000 + 1000 = 11_000
        
        uint256 amount = 10;
        uint256 incomingBoostedStakedTokens = (amount * vaultTotalBoostFactor) / PRECISION_BASE; // amount * (11_000/10_000) = amount * 11

        return incomingBoostedStakedTokens; // RETURNS 11
    }
```

Exceeding `10_000` is acceptable for NFT_MULTIPLIER, and it can still retain 2dp precision.

```solidity
    function nftPrecision() public pure returns(uint256) {
        
        uint256 PRECISION_BASE = 10_000;
        
        uint256 amount = 1 ether;
        uint256 vault_totalBoostFactor = 20_050 * 1;  // assume 1 nft staked
        // 20_050 = 200.5%

        uint256 incomingBoostedStakedTokens = (amount * vault_totalBoostFactor) / PRECISION_BASE;

        return incomingBoostedStakedTokens;
        // 1 ether: 2005000000000000000 = 2.005 tokens 
        // 1.23 ether: 2466150000000000000 = 2.46615 tokens -> 200.5%
    }
```

**In the above example, by setting `NFT_MULTIPLIER` to `20_050`, we are able to retain 2dp precision; which is reflective of 200.5% boost.**

### 2.2 Fee Factors

Fee factors cannot exceed `5000`, as this would be equivalent to 50% fee.
In  `createVault`, we check if the total fee factor exceeds `5000`:

```solidity
        uint256 totalFeeFactor = fees.nftFeeFactor + fees.creatorFeeFactor + fees.realmPointsFeeFactor;
        if(totalFeeFactor > 5000) revert TotalFeeFactorExceeded();
```

**This is to ensure that MOCA stakers receive at least 50% of rewards.**

In `_updateUserAccount`, we calculate the fees accrued by the user:

```solidity
    // calc. creator fees
    if(vault.creatorFeeFactor > 0) {
        accCreatorFee = (totalAccRewards * vault.creatorFeeFactor) / PRECISION_BASE;
    }

    // nft fees accrued only if there were staked NFTs
    if(vault.stakedNfts > 0) {
        if(vault.nftFeeFactor > 0) {

            accTotalNftFee = (totalAccRewards * vault.nftFeeFactor) / PRECISION_BASE;
            vaultAccount.nftIndex += (accTotalNftFee / vault.stakedNfts);              // nftIndex: rewardsAccPerNFT
        }
    }

    // rp fees accrued only if there were staked RP 
    if(vault.stakedRealmPoints > 0) {
        if(vault.realmPointsFeeFactor > 0) {
            accRealmPointsFee = (totalAccRewards * vault.realmPointsFeeFactor) / PRECISION_BASE;

            // accRealmPointsFee is in reward token precision
            uint256 stakedRealmPointsRebased = (vault.stakedRealmPoints * distribution.TOKEN_PRECISION) / 1E18;  
            vaultAccount.rpIndex += (accRealmPointsFee / stakedRealmPointsRebased);              // rpIndex: rewardsAccPerRP
        }
    } 
```

### 2.3 PrecisionBase reference

If we only wanted to express fee factors in integer values, (meaning 0 precision), we could set `PRECISION_BASE` to `100`.

- 100% : 100
- 50%  : 50
- 1%   : 1
- 0.5% : 5
- 0.25%: 2.5
- 0.05%: 0.5
- 0.01%: 0.1

---

# Distributions


    /** track token distributions

        each distribution has an id
        two different distributionsIds could lead to the same token - w/ just different distribution schedules
        
        each time a vault is updated we must update all the active tokenIndexes,
        which means we must loop through all the active indexes.
     */


    /**
        users create vaults for staking
        tokens are distributed via distributions
        distributions are created and managed on an ad-hoc basis
     */

staking power

    // staking power is distributionId:0 => tokenData{uint256 chainId:0, bytes32 tokenAddr: 0,...}

# Contract Walkthrough

## Constructor & Initial setup

```solidity
    constructor(address registry, address stakedToken, uint256 startTime_, uint256 nftMultiplier, uint256 creationNftsRequired, uint256 vaultCoolDownDuration,
        address owner) payable Ownable(owner) {...}
```

On deployment, the following must be defined:

1. address of nft registry contract
2. address of staked token
3. startTime: user are only able to call staking functions after startTime.
4. nftMultiplier: multiplier factor per nft
5. creationNftsRequired: number of nfts required to create a vault
6. vaultCoolDownDuration: cooldown period of vault before ending permanently

This expects that the nft registry contract should be deployed in advance.

We need to then deploy the following contracts:
- RewardsVault
- RealmPoints

We need to then set the following, on the stakingPro contract:
- RewardsVault address
- RealmPoints address

## Roles & Addresses

Addresses:

1. Owner multiSig
2. Risk monitoring script [EOA]
3. Operator [EOA]

Roles:

1. MONITOR_ROLE: can only call pause(); for risk monitoring scripts
2. OPERATOR_ROLE: for update various pool parameters and stakeOnBehalfOf()
3. DEFAULT_ADMIN_ROLE: Owner multiSig; can assign/revoke roles to other addresses

### Owner multiSig address is assigned:

1. MONITOR_ROLE
2. OPERATOR_ROLE
3. DEFAULT_ADMIN_ROLE

With the default admin role, it can assign/revoke roles to other addresses.
With the monitor role, it can call pause(); to pause the contract.
With the operator role, it can call update various pool parameters and stakeOnBehalfOf().

### Risk monitoring script address is assigned:

1. MONITOR_ROLE

With the monitor role, it can call pause(); to pause the contract.

### Operator address is assigned:

1. OPERATOR_ROLE

With the operator role, it can call update various pool parameters.
On deployment, no operator address is assigned. When required, the DAT team is to call `grantRole(bytes32 role, address account)` to assign the operator role to the supplied address.

Once the necessary changes are made, the operator address is to call `revokeRole(bytes32 role, address account)` to revoke the operator role from itself.
This is to ensure that the operator role is kept unassigned, unless it is required.

## Pool States

- ended
- paused/unpaused
- frozen
- underMaintenance

1. ended: contract is ended, as dictated by its endTime. Users can only claim rewards and unstake.
2. paused: contract is paused, all user functions revert.
3. frozen: contract is frozen, all user functions revert except for emergencyExit().
4. underMaintenance: contract is under maintenance, all user functions revert.

### Under Maintenance

Contract is set to `underMaintenance` when there is a need to update the NFT_MULTIPLIER value.

Process:
    1. enableMaintenance
    2. updateDistributions
    3. updateAllVaultAccounts
    4. updateNftMultiplier
    5. updateBoostedBalances
    6. disableMaintenance

Setting the contract to `underMaintenance` will prevent users from staking, unstaking, claiming rewards, or creating new vaults.
This is to ensure that the NFT_MULTIPLIER is updated correctly, and that the boosted balances are updated correctly.

### Pause/Unpause

Contract is set to `paused` when there is a need to assess for possible security issues.
If there are no security issues, the contract can be unpaused.

If there are security issues, the contract is frozen.

### Frozen

Contract is set to `frozen` when there are irreparable issues with the contract.
This is to prevent any further damage to the contract, and to ensure that the contract is not used anymore.

Once frozen, users can only call `emergencyExit()`, which will allow users to reclaim their principal staked assets.
Any unclaimed rewards and fees are forfeited.

Note: `emergencyExit()` assumes that the contract is broken and any state updates made to be invalid; hence it does not update rewards and fee calculations.

# User functions

## createVault

```solidity
createVault(
    uint256[] calldata tokenIds, 
    uint256 nftFeeFactor, 
    uint256 creatorFeeFactor, 
    uint256 realmPointsFeeFactor) external whenStartedAndNotEnded whenNotPaused whenNotUnderMaintenance
```

Creates a new vault for staking with specified fee parameters:

- nftMultiplier: multiplier factor per nft
- creationNftsRequired: number of nfts required to create a vault
- vaultCoolDownDuration: cooldown period of vault before ending permanently

Requires the creator to have the required number of nfts.
These nfts are locked, and do not count towards rewards calculations.

## stakeTokens

```solidity
stakeTokens(bytes32 vaultId, uint256 amount) external whenStartedAndNotEnded whenNotPaused whenNotUnderMaintenance
```

Allows users to stake tokens into a specified vault:

- Checks that the vault exists and is not ended
- Transfers tokens from user to contract

Note that staking tokens does not automatically stake NFTs or Realm Points - these must be staked separately via their respective functions.

## stakeNfts

```solidity
stakeNfts(bytes32 vaultId, uint256[] calldata tokenIds) external whenStartedAndNotEnded whenNotPaused whenNotUnderMaintenance
```

Allows users to stake NFTs into a specified vault:

- Checks that the vault exists and is not ended
- Calls NFT_REGISTRY.checkIfUnassignedAndOwned(), to check if the NFTs are unassigned and owned by the user
- Calls NFT_REGISTRY.recordStake(), to record vault assignment so that the NFTs cannot be staked in another vault

The staked NFTs contribute to boosting the vault's staked Tokens and Realm Points, which determines its share of rewards from active distributions.

## stakeRP

```solidity
stakeRP(bytes32 vaultId, uint256 amount, uint256 expiry, bytes calldata signature) external whenStartedAndNotEnded whenNotPaused whenNotUnderMaintenance
```

Allows users to stake Realm Points into a specified vault:

- Checks that the vault exists and is not ended
- Amount must be greater than `MINIMUM_REALMPOINTS_REQUIRED`
- Signature must not be expired or already executed
- Signature must be valid and from the stored signer

## unstakeAll

```solidity
unstakeAll(bytes32 vaultId) external whenStartedAndNotEnded whenNotPaused whenNotUnderMaintenance
```

Allows users to unstake all their staked tokens and Nfts from a specified vault:

- Checks that the vault exists and is not ended
- Unstakes all staked tokens and Nfts
- Updates NFT_REGISTRY to record unstake (NFT_REGISTRY.recordUnstake)

## migrateVaults

```solidity
migrateVaults(bytes32 oldVaultId, bytes32 newVaultId) external whenStartedAndNotEnded whenNotPaused whenNotUnderMaintenance 
```

Allows users to migrate their staked tokens and Nfts from one vault to another:

- Checks that the old vault exists
- Checks that the new vault exists and is not ended
- Migrates all staked tokens and Nfts from the old vault to the new vault
- Calls NFT_REGISTRY to record unstake on the old vault, and stake on the new vault

## claimRewards

```solidity
claimRewards(bytes32 vaultId, uint256 distributionId) external whenStartedAndNotEnded whenNotPaused whenNotUnderMaintenance
```

Allows users to claim rewards from a specified vault:

- Checks that the distributionId is not 0.
- Calls RewardsVault to transfer rewards to the user

## updateVaultFees

```solidity
updateVaultFees(bytes32 vaultId, uint256 nftFeeFactor, uint256 creatorFeeFactor, uint256 realmPointsFeeFactor) external whenStartedAndNotEnded whenNotPaused whenNotUnderMaintenance
```

Updates the fees for a specified vault:

- Only the vault creator can update fees
- Creator can only decrease their creator fee factor
- Total of all fees cannot exceed 50% [MocaToken stakers receive at least 50% of rewards]

## activateCooldown

```solidity
activateCooldown(bytes32 vaultId) external whenStartedAndNotEnded whenNotPaused whenNotUnderMaintenance
```

Activates the cooldown period for a vault:

- If `VAULT_COOLDOWN_DURATION` is 0, vault is immediately removed from circulation
- When removed, all vault's staked assets are deducted from global totals

If `VAULT_COOLDOWN_DURATION` is of non-zero value, the vault's endTime is set to `block.timestamp` + `VAULT_COOLDOWN_DURATION`.
While this sets the endTime of the vault, it does not necessarily mean that the vault will be removed from circulation immediately.
That would be handled by the `endVaults()` function.

## endVaults

```solidity
endVaults(bytes32[] calldata vaultIds) external onlyOwner
```

- Ends multiple vaults
- Removes all staked assets from circulation and updates global totals
- Callable by anyone; no access control restrictions
- Checks if endTime was set, as per `activateCooldown()`, else skips to next vault

## stakeOnBehalfOf

```solidity
stakeOnBehalfOf(bytes32[] calldata vaultIds, address[] calldata onBehalfOfs, uint256[] calldata amounts) external whenStartedAndNotEnded whenNotPaused whenNotUnderMaintenance onlyOperatorOrOwner
```

Allows the operator/owner to stake on behalf of users:

- Checks that the vault exists and is not ended
- Transfers tokens from the function caller to the contract



# Pool Management functions

## setEndTime

```solidity
setEndTime(uint256 endTime_) external whenNotEnded whenNotPaused onlyOperatorOrOwner
```

- endTime can be moved forward or backward; as long its a future timestamp
- Only callable when contract is not ended or frozen

## setRewardsVault

```solidity
setRewardsVault(address newRewardsVault) external whenNotEnded whenNotPaused onlyOperatorOrOwner
```

- Updates the rewards vault address; cannot be set to a zero address
- Only callable when contract is not ended or frozen
- Should only be updated when there are no active distributions, else reverts and txn fails will occur.

Key aspects:

- Allows deploying enhanced rewards vault contracts without modifying StakingPro
- Preserves all staked assets and earned rewards
- Takes effect immediately for future reward distributions

This provides flexibility to upgrade reward distribution logic while maintaining core staking functionality.

## updateMinimumRealmPoints

```solidity
updateMinimumRealmPoints(uint256 newAmount) external whenNotEnded whenNotPaused onlyOperatorOrOwner
```

- Updates the storage variable `MINIMUM_REALMPOINTS_REQUIRED`; which is referenced in `stakeRP()`.
- Can increase/decrease it to adjust the barrier to entry.
- Zero amount not allowed.

## updateCreationNfts

```solidity
updateCreationNfts(uint256 newAmount) external whenNotEnded whenNotPaused onlyOperatorOrOwner
```

- Updates the storage variable `CREATION_NFTS_REQUIRED`; which is referenced in `createVault()`.
- Zero values are accepted, allowing vault creation without NFT requirements.

## updateVaultCooldown

```solidity
updateVaultCooldown(uint256 newDuration) external whenNotEnded whenNotPaused onlyOperatorOrOwner
```

- Updates the storage variable `VAULT_COOLDOWN_DURATION`; which is referenced in `activateCooldown()`.
- Zero values are accepted, allowing vaults to be ended immediately.

## setupDistribution

```solidity
setupDistribution(uint256 distributionId, uint256 distributionStartTime, uint256 distributionEndTime, uint256 emissionPerSecond, uint256 tokenPrecision,
        uint32 dstEid, bytes32 tokenAddress
    ) external whenNotEnded whenNotPaused onlyOperatorOrOwner 
```

Creates a new distribution with specified parameters:

- distributionId: Unique identifier for the distribution
- distributionStartTime: When distribution begins emitting rewards
- distributionEndTime: When distribution stops emitting rewards
- emissionPerSecond: Rate of reward token emissions
- tokenPrecision: Decimal precision of the reward token (e.g. 1e18)
- dstEid: EID of the destination chain
- tokenAddress: Address of the reward token

### Staking Power

- Distribution Id 0 is reserved for staking power
- It can be set to have indefinite endTime.
- Does not require a dstEid or tokenAddress.

### Token setup

- both start and end times must be defined
- else, we would be emitting token rewards indefinitely
- calls RewardsVault to setup the Distribution there as well
- does not expect tokens to have been deposited; that comes after the distribution is setup

### LayerZero

- dstEid: EID of the destination chain
- tokenAddress: Address of the reward token

Use of bytes32 for tokenAddress is to standardize across evm and non-evm chains.

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
updateDistribution(uint256 distributionId, uint256 newStartTime, uint256 newEndTime, uint256 newEmissionPerSecond) external whenNotEnded whenNotFrozen onlyOperatorOrOwner
```

Allows modification of parameters of an existing distribution:

- distributionId: ID of the distribution to update
- newStartTime: Can only be modified if distribution hasn't started yet. Must be in the future.
- newEndTime: Can be extended or shortened, but must be after current timestamp [`newEndTime > block.timestamp`]
- newEmissionPerSecond: Can be modified at any time to adjust reward rate

Key constraints:

- At least one parameter must be modified (non-zero)
- Cannot modify start time after distribution has begun
- New end time must be after start time
- Cannot set emission rate to 0
- Cannot modify ended distributions

This function enables flexible management of reward distributions by allowing adjustments to timing and emission rates while maintaining key invariants.

## endDistributionImmediately

```solidity
endDistributionImmediately(uint256 distributionId) external whenNotEnded whenNotFrozen onlyOperatorOrOwner
```

Allows owner to immediately terminate an active distribution:

- distributionId: ID of the distribution to end
- Enables emergency termination of a distribution by setting its end time to the current block timestamp. 
- Effectively stops any further rewards from being distributed while preserving all rewards earned up to that point.
- Distribution must exist and be active (not ended).
- Calls RewardsVault to set the flag `manuallyEnded=1`

This provides an emergency mechanism to halt reward distributions if needed, while ensuring already-earned rewards remain claimable.

# Maintenance Mode functions [To update: NFT_Multiplier]

## enableMaintenance

```solidity
enableMaintenance() external whenNotPaused whenNotUnderMaintenance onlyOperatorOrOwner 
```

- Enables maintenance mode, which disables all user functions.
- Only callable when contract is not paused.

## disableMaintenance

```solidity
disableMaintenance() external whenNotPaused whenUnderMaintenance onlyOperatorOrOwner
```

- Disables maintenance mode, which re-enables all user functions.
- Only callable when contract is not paused.

## updateDistributions

```solidity
updateDistributions() external whenNotEnded whenNotPaused whenUnderMaintenance onlyOperatorOrOwner
```

- Updates all active distribution indexes to current timestamp
- This ensures all rewards are properly calculated and booked
- Only callable when contract is under maintenance.

## updateAllVaultAccounts

```solidity
updateAllVaultAccounts(bytes32[] calldata vaultIds) external whenNotEnded whenNotPaused whenUnderMaintenance onlyOperatorOrOwner
```

- Updates all vault accounts for all active distributions
- This ensures all rewards are properly calculated and booked
- Only callable when contract is under maintenance.

## updateNftMultiplier

```solidity
updateNftMultiplier(uint256 newMultiplier) external whenNotEnded whenNotPaused whenUnderMaintenance onlyOperatorOrOwner
```

- Updates the NFT multiplier
- Only callable when contract is under maintenance.

## updateBoostedBalances

```solidity
updateBoostedBalances(bytes32[] calldata vaultIds) external whenNotEnded whenNotPaused whenUnderMaintenance onlyOperatorOrOwner
```

- This function is expected to be called multiple times, until all vaults have been updated to use the latest `NFT_MULTIPLIER` value
- Also updates the global boosted balances, based on the delta of the update to vault's boosted balances

**After cycling through all vaults, we should sanity check that the updated global boosted balances match up with the expected values. If they do not match up, we should end the contract and redeploy.**

# Risk Management functions

## pause

```solidity
pause() external whenNotPaused onlyRole(MONITOR_ROLE)
```
- pause contract
- only callable by MONITOR_ROLE
- MONITOR_ROLE is expected to be assigned to the monitoring script as well as owner multiSig

## unpause

```solidity
unpause() external whenPaused onlyRole(DEFAULT_ADMIN_ROLE)
```

- unpause contract
- only callable by DEFAULT_ADMIN_ROLE

## freeze

```solidity
freeze() external whenNotFrozen onlyRole(DEFAULT_ADMIN_ROLE)
```

- freeze contract
- only callable by DEFAULT_ADMIN_ROLE

## emergencyExit

Assuming black swan event, users call `emergencyExit` to exit.

1. pause(): all user fns are disabled
2. freeze(): cannot unpause; only emergencyExit() can be called
3. emergencyExit(): exfil all principal assets

```solidity
emergencyExit(bytes32[] calldata vaultIds, address onBehalfOf) external whenStarted whenPaused whenNotUnderMaintenance
```

- only callable when contract is paused and frozen
- callable by users to exfil their assets
- Rewards and fees are not withdrawn; indexes are not updated. Preserves state history at time of failure.

- This allows users to recover their principal assets in a black swan event.
- It does not allow users to recover their rewards or fees.

**This is the contrasting point versus calling `unstakeAll` and `emergencyExit`. Why?**

- The assumption here is that the contract can no longer be trusted, and calculations and updates should not be trusted or engaged with.
- So we only look to recover the principal assets.
- Can worry about calculating what is owed off-chain at our leisure once users assets are secured.

**Function is callable by anyone, but asset transfers are made to the correct beneficiary**

- This is done by checking the `onBehalfOf` address.
- The reason for this is to allow both users and us to call the function, to allow for a swift exit.

# Notes

## 1. explain the process of updating each vaultAccount and userAccount for a specific user's vault

```solidity
        /**
            user to stake in a specific vault
            that vault must be updated and booked first
            - update all active distributions
            - update all vault accounts for specified vault [per distribution]
            - update all user accounts for specified vault  [per distribution]
            - book stake and update vault assets
            - book stake 
         */


        // update all vault accounts for specified vault [per distribution]
        // - update all active distributions: book prior rewards, based on prior alloc points
        // - update all vault accounts for each active distribution 
        // - update user's account

```
## 2. how rewards are calculated: distribution, vault, user

# Execution Flow

## 1. Creating a distribution

- called on stakingPro
- has nested call to rewardsVault to communicate necessary values: `totalRequired`, `dstEid`, `tokenAddress` (bytes32)
- `totalRequired` is the total amount of tokens required to be deposited
- `dstEid` is the destination EID, (assuming its a remote token)
- `tokenAddress` is the address of the token to be deposited
- `tokenAddress` is stored as bytes32, to standardize across evm and non-evm chains

Nested call within stakingPro so that we do not have to make 2 independent txns to setup distribution; reducing human error.

**The rewardsVault must be set before any distributions can be created**
- If this address has not been set, distributions cannot be created, as the nested call to rewardsVault will revert.
- Address cannot be set to a zero address.
- If RewardsVault contract is paused, distributions cannot be created or ended, rewards cannot be claimed. [revert]

## 2. Deposit tokens

### Local token

- token exists on the same chain as the stakingPro
- MONEY_MANAGER to call deposit() on rewardsVault
- `deposit(uint256 distributionId, uint256 amount, address from) onlyRole(MONEY_MANAGER_ROLE) external`

### Remote token

- token exists on a different chain as the stakingPro
- MONEY_MANAGER to call deposit() on evmVault, which exists on the remote chain
- `deposit(address token, uint256 amount, address from, uint256 distributionId) external payable onlyOwner`
- this is a LZ enabled fn, so it is payable
- will fire off a xchain message to the home chain, to update rewardsVault
- `totalDeposited` is incremented on rewardsVault

## 3. Withdraw tokens

### Local token

- MONEY_MANAGER to call withdraw() on rewardsVault
- `withdraw(uint256 distributionId, uint256 amount, address to) onlyRole(MONEY_MANAGER_ROLE) external`

### Remote token

- MONEY_MANAGER to call withdraw() on evmVault, which exists on the remote chain
- `withdraw(address token, uint256 amount, address to, uint256 distributionId) external onlyOwner`
- this is a LZ enabled fn, so it is payable
- will fire off a xchain message to the home chain, to update rewardsVault
- `totalDeposited` is decremented on rewardsVault

## 4. claimRewards

- user to call claimRewards() on stakingPro
- `claimRewards(bytes32 vaultId, uint256 distributionId) external`
- after calculating rewards, will make an external call to rewardsVault to transfer rewards to user
- if the token is local, rewardsVault will transfer the rewards to the user
- if the token is remote, rewardsVault will fire off a xchain message to the remote chain, hitting the evmVault there and instructing it to transfer rewards to the user
- `totalClaimed` is incremented on rewardsVault

Note that the rewardsVault only supports local, other remote evm chains and solana.

![alt text](image.png)

## 5. Cooldown & Ending vaults: activateCooldown() and endVaults()

### activateCooldown()

- activateCooldown() is called when the vault creator wants to activate the cooldown period of a vault
- this signifies that the vault will come to an end in the near future
- `vault.endTime` is set to `block.timestamp` + `VAULT_COOLDOWN_DURATION`
- once `vault.endTime` is a non-zero value, users would not be able to stake anymore
- however user can continue to claim rewards and unstake at their leisure

Upon calling activateCooldown(), the creation NFTs are unlocked, allowing the creator to create new vaults.

### endVaults() [!!!]

- endVaults() is called when the vault's end time is reached and the weight of its staked assets must be removed from the system; so they do not accrue rewards nor dilute the rewards of the other active vaults
- this is necessary as there is no automated manner for this to occur without drift
- currently this is callable by anyone, with no access control restrictions
- vault's staked assets are removed from the system
- global boosted balances are also decremented

The expectation is that we call endVaults() on all the vaults that have come to an end, via script.

[!!!]: confirm that _udpateVaultsAndAccounts() is failing after endtime. consider a removed check?

## 6. Updating NFT_MULTIPLIER (pause, update, unpause)

Process:

1. call `updateDistributionsAndPause()`: updates all distribution indexes, then pauses contract.
2. call `updateAllVaultAccounts()`: updates all vault indexes
3. update NFT multiplier: `updateNftMultiplier()`
4. recalculate boostedBalance: `updateBoostedBalances(bytes32[] calldata vaultIds)`
5. call `unpause()`: unpauses contract.

We will need to call `updateBoostedBalances()` multiple times for all vaults that have been updated.
During this process, user functions are disabled, as calling them during this process will result in incorrect calculations.

E.g. an unstake() could slip in btw `updateBoostedBalances()` calls and wreck havoc on calculations.

Hence, lock the contract, update, verify that the updated totalBoosted global values tally with the expected values.
If verification fails, end the contract and redeploy.

When all the vaults have been updated to use the latest `NFT_MULTIPLIER` value, `totalBoostedStakedTokens` and `totalBoostedRealmPoints` should match up.
This serves as a sanity check to ensure that the multiplier is updated correctly, as well as the vaults are updated correctly.

Note: `_updateDistributionIndex` returns if paused. This prevents multiple updates to distribution indexes during `updateAllVaultAccounts()`.

## 7. How to end stakingPro and/or migrate to a new stakingPro contract (endTime)

- Set endTime global variable via `setEndTime`.
- Users will be able to call: `unstakeAll` and `claimRewards` after `endTime`.
- `setEndTime` can be called repeatedly, by owner, to update `endTime`.
- `endTime` can be moved forward or backward.

**What if endTime is set, but there are still active distributions continuing beyond endTime?**

- `unstake` and `claimRewards` are callable even after `endTime`.
- Calling these functions after `endTime` would mean that if there are still active distributions, the distributions would be updated via _updateUserAccounts::_updateDistributionIndex.

Hence, when calling `setEndTime`, we should check if there are still active distributions beyond endTime.
If there are, we should end those distributions via `updateDistribution`.

>It is not possible to nest `claimRewards` within `unstakeAll`, as `claimRewards` operates on a per-distribution basis. Hence, 2 functions are needed.

## 9. Ending a distribution

- `endDistributionImmediately(uint256 distributionId)`
- This function enables immediate termination of a distribution by setting its end time to the current block timestamp. 
- This effectively stops any further rewards from being distributed while preserving all rewards earned up to that point.
- Distribution must exist and be active (not ended).

## 10. States

unpaused
- all normal fns

paused
- claimRewards

frozen
- emergencyExit

why disallow unstake when paused?
- so that can update NFT multipliers w/o distruption
- if users can unstake - this impacts base staked assets as well as boosted staked assets - causing drift in calculations
- remember updateAllVaultsAndAccounts() is to executed repeatedly, and an unstake() could slip in btw calls the wreck havoc on calculations.