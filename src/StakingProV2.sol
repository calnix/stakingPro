// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import './Events.sol';
import {Errors} from './Errors.sol';
import {DataTypes} from './DataTypes.sol';

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

// interfaces
import {INftRegistry} from "./interfaces/INftRegistry.sol";
import {IRewardsVault} from "./interfaces/IRewardsVault.sol";


contract StakingPro is Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    INftRegistry public immutable NFT_REGISTRY;
    IRewardsVault public immutable REWARDS_VAULT;

    uint256 public immutable startTime; // can start arbitrarily after deployment
    uint256 public endTime;             // if we need to end 

    // staked assets
    uint256 totalStakedNfts;
    uint256 totalStakedTokens;
    uint256 totalStakedRealmPoints;

    // boosted balances
    uint256 totalBoostedRealmPoints;
    uint256 totalBoostedStakedTokens;

    // pool emergency state
    bool public isFrozen;

    //------- modifiables -------------

    // creation nft requirement
    uint256 public creationNftsRequired = 5;

    uint256 public NFT_MULTIPLIER = 0.1 * 1e18; // 0.1 * 1e18 = 10%
    
    //--------------------------------

    /** track token distributions

        each distribution has an id
        two different distributionsIds could lead to the same token - w/ just different distribution schedules
        
        each time a vault is updated we must update all the active tokenIndexes,
        which means we must loop through all the active indexes.
     */
    // array stores key values for distributions mapping 
    uint256[] public activeDistributions;    // we do not expect a large number of concurrently active distributions
    uint256 public totalDistributions;
    uint256 public completedDistributions;

//-------------------------------mappings--------------------------------------------

    /**
        users create vaults for staking
        tokens are distributed via distributions
        distributions are created and managed on an ad-hoc basis
     */

    // vault base attributes
    mapping(bytes32 vaultId => DataTypes.Vault vault) public vaults;

    // just stick staking power as distributionId:0 => tokenData{uint256 chainId:0, bytes32 tokenAddr: 0,...}
    mapping(uint256 distributionId => DataTypes.Distribution distribution) public distributions;

    // global tracking of user assets
    mapping(address user => DataTypes.User user) public users;

    // user's assets per vault
    mapping(address user => mapping(bytes32 vaultId => DataTypes.User user)) public usersVaultAssets;

    // for independent reward distribution tracking              
    mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) public vaultAccounts;

    // rewards accrued per user, per distribution
    mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) public userAccounts;

//-------------------------------constructor------------------------------------------

    constructor(address registry, address rewardsVault, uint256 startTime_, uint256 emissionPerSecond, address owner) payable Ownable(owner) {

        // sanity check input data: time, period, rewards
        require(owner > address(0), "Zero address");
        require(emissionPerSecond > 0, "emissionPerSecond = 0");
        require(startTime_ > block.timestamp, "Invalid startTime");

        // interfaces: supporting contracts
        NFT_REGISTRY = INftRegistry(registry);              
        REWARDS_VAULT = IRewardsVault(rewardsVault);    

        // set startTime 
        startTime = startTime_;

        // setup staking power
        DataTypes.TokenData memory vault = vaults[0]; 
            // tokenAddr and chainId are intentionally left 0
            vault.precision = 1e18;

            vault.startTime = startTime_;
            vault.emissionPerSecond = emissionPerSecond;
            
            vault.lastUpdateTimeStamp = startTime_;

        vaults[0] = vault;

        // update vault tracking
        activeVaults.push();
        ++ totalVaults;

        emit DistributionUpdated(emissionPerSecond, startTime);
    }


//-------------------------------external---------------------------------------------

    /**
      * @notice Creates empty vault
      * @dev Nfts must be committed to create vault. Creation NFTs are locked to create vault
     */
    function createVault(address onBehalfOf, uint256[] calldata tokenIds, DataTypes.Fees calldata fees) external whenStarted whenNotPaused {

        // must commit unstaked NFTs to create vaults: these do not count towards stakedNFTs
        uint256 incomingNfts = tokenIds.length;
        if(incomingNfts != creationNftsRequired) revert Errors.IncorrectCreationNfts();
        
        for (uint256 i; i < creationNftsRequired; i++) {

            (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds[i]);
            
            if(owner != onBehalfOf) revert Errors.IncorrectNftOwner(tokenIds[i]);
            if(nftVaultId != bytes32(0)) revert Errors.NftAlreadyStaked(tokenIds[i]);
        }

        //note: MOCA stakers must receive ≥50% of all rewards
        uint256 totalFeeFactor = fees.nftFeeFactor + fees.creatorFeeFactor + fees.realmPointsFeeFactor;
        require(totalFeeFactor <= 50, "Cannot exceed 50%");

        // vaultId generation
        bytes32 vaultId;
        {
            uint256 salt = block.number - 1;
            vaultId = _generateVaultId(salt, onBehalfOf);
            while (vaults[vaultId].vaultId != bytes32(0)) vaultId = _generateVaultId(--salt, onBehalfOf);      // If poolId exists, generate new random Id
        }
        // build vault
        DataTypes.Pool memory vault; 
            vault.vaultId = vaultId;
            vault.creator = onBehalfOf;
            vault.creationTokenIds = tokenIds;  
            
            vault.startTime = block.timestamp; 

            // fees
            vault.nftFeeFactor = fees.nftFeeFactor;
            vault.creatorFeeFactor = fees.creatorFeeFactor;
            vault.realmPointsFeeFactor = fees.realmPointsFeeFactor;
            
            // boost factor: Initialize totalBoostFactor to 1e18 (100%)
            vault.totalBoostFactor = 1e18;  // Base 100%

        // update storage
        vaults[vaultId] = vault;

        //update: emit VaultCreated(onBehalfOf, poolId); //emit totaLAllocPoints updated?

        // record NFT commitment on registry contract
        NFT_REGISTRY.recordStake(onBehalfOf, tokenIds, poolId);
    }  

    // no staking limits on staking assets
    function stakeTokens(bytes32 vaultId, address onBehalfOf, uint256 amount) external whenStarted whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(vaultId > 0, "Invalid vaultId");
 
        // check if vault exists + cache vault & user's vault assets
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);
     
        //_updateUserIndexes -> _updateVaultIndex::calc_Rewards -> _updatePoolIndex
        //_updateUserAccounts  -> _updateVaultAccounts::calc_Rewards for each activeDistribution -> _updateDistributionIndexes::_updateDistributionIndex

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
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        // calc. boostedStakedTokens
        uint256 incomingBoostedStakedTokens = (amount * vault.totalBoostFactor);
        
        // increment: vault
        vault.stakedTokens += amount;
        vault.boostedStakedTokens += incomingBoostedStakedTokens;

        //increment: userVaultAssets
        userVaultAssets.stakedTokens += amount;
        userVaultAssets.boostedStakedTokens += incomingBoostedStakedTokens;

        //increment: user global
        //......

        // update storage: mappings 
        vaults[vaultId] = vault;
        usersVaultAssets[onBehalfOf][vaultId] = userVaultAssets;

        // update storage: variables
        totalStakedTokens += amount;
        totalBoostedStakedTokens += incomingBoostedStakedTokens;
        
        // emit StakedMoca(onBehalfOf, vaultId, amount);

        // grab MOCA
        STAKED_TOKEN.safeTransferFrom(onBehalfOf, address(this), amount);
    }

    // no staking limits on staking assets
    function stakeNfts(bytes32 vaultId, address onBehalfOf, uint256[] calldata tokenIds) external whenStarted whenNotPaused {
        uint256 incomingNfts = tokenIds.length;

        require(incomingNfts > 0, "Invalid amount"); 
        require(vaultId > 0, "Invalid vaultId");

        // check if vault exists + cache vault & user's vault assets
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);

        // Update all distributions, their respective vault accounts, and user accounts for specified vault
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        //if(endTime <= block.timestamp) --> note: what to do when pool has reached endTime and not extended?         

        // cache
        uint256 oldBoostedRealmPoints = vault.boostedRealmPoints;
        uint256 oldBoostedStakedTokens = vault.boostedStakedTokens;

        // update: vault's nfts 
        vault.stakedNfts += incomingNfts;
               
        // update boost factor: each NFT adds 0.1 (10%) boost, so for N NFTs, add N * 0.1 to the boost factor
        uint256 boostFactorDelta = incomingNfts * NFT_MULTIPLIER;
        vault.totalBoostFactor += boostFactorDelta;     // totalBoostFactor is expressed as 1.XXX; in 1e18 precision

        // recalc. boosted balances with new boost factor 
        if (vault.stakedTokens > 0) vault.boostedStakedTokens = (vault.stakedTokens * vault.totalBoostFactor) / 1e18;            
        if (vault.stakedRealmPoints > 0) vault.boostedRealmPoints = (vault.stakedRealmPoints * vault.totalBoostFactor) / 1e18;

        // update: user's tokenIds + boostedBalances
        userVaultAssets.tokenIds = _concatArrays(userVaultAssets.tokenIds, tokenIds);   //note: what does concat an empty arr do -- on first instance?
        userVaultAssets.boostedStakedTokens = (userVaultAssets.stakedTokens * vault.totalBoostFactor) / 1e18;  
        userVaultAssets.boostedRealmPoints = (userVaultAssets.stakedRealmPoints * vault.totalBoostFactor) / 1e18;

        // update storage: mappings 
        vaults[vaultId] = vault;
        usersVaultAssets[onBehalfOf][vaultId] = userVaultAssets;

        // update storage: global variables 
        totalStakedNfts += incomingNfts;
        totalBoostedRealmPoints += (vault.boostedRealmPoints - oldBoostedRealmPoints);
        totalBoostedStakedTokens += (vault.boostedStakedTokens - oldBoostedStakedTokens);

        emit StakedMocaNft(onBehalfOf, vaultId, tokenIds);
        emit VaultMultiplierUpdated(vaultId, oldMultiplier, vault.multiplier);

        // record stake with registry
        NFT_REGISTRY.recordStake(onBehalfOf, tokenIds, vaultId);
    }

    // claim token rewards. not applicable to distributionId:0 
    // users can only claim all reward types from 1 token type at once. 
    function claimRewards(bytes32 vaultId, address onBehalfOf, uint256 distributionId) external whenStarted whenNotPaused {
        require(vaultId > 0, "Invalid vaultId");
        require(distributionId > 0, "N/A: Staking Power");

        // check if vault exists + cache vault & user's vault assets
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);

        // Update all distributions, their respective vault accounts, and user accounts for specified vault
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        //get accounts for specified distribution
        DataTypes.VaultAccount memory vaultAccount = vaultAccounts[vaultId][distributionId];
        DataTypes.UserAccount memory userAccount = userAccounts[onBehalfOf][vaultId][distributionId];

        //note: does he have anything to claim?
        // - RP, MOCA, NFTs could be staked at diff times       

        //------- calc. and update vault and user accounts --------

        // update balances: staking MOCA rewards
        uint256 unclaimedRewards = userAccount.accStakingRewards - userAccount.claimedStakingRewards;
        userAccount.claimedStakingRewards += unclaimedRewards;
        vaultAccount.totalClaimedRewards += unclaimedRewards;

        // update balances: staking RP rewards
        uint256 unclaimedRpRewards = userAccount.accRealmPointsRewards - userAccount.claimedRealmPointsRewards;
        userAccount.claimedRealmPointsRewards += unclaimedRpRewards;
        vaultAccount.totalClaimedRewards += unclaimedRpRewards;

        // update balances: staking NFT rewards
        uint256 unclaimedNftRewards = userAccount.accNftStakingRewards - userAccount.claimedNftRewards;
        userAccount.claimedNftRewards += unclaimedNftRewards;
        vaultAccount.totalClaimedRewards += unclaimedNftRewards;

        //if creator
        if(vault.creator == onBehalfOf){
            uint256 unclaimedCreatorRewards = vaultAccount.accCreatorRewards - userAccount.claimedCreatorRewards;
            userAccount.claimedCreatorRewards += unclaimedCreatorRewards;
            vaultAccount.totalClaimedRewards += unclaimedCreatorRewards;
        }

        //------- ........................................... --------

        //update storage: vault and user accounts
        vaultAccounts[vaultId][distributionId] = DataTypes.VaultAccount memory vaultAccount;
        userAccounts[onBehalfOf][vaultId][distributionId] = DataTypes.UserAccount memory userAccount;

        // emit RewardsClaimed(vaultId, onBehalfOf, unclaimedRewards);

        // note: UPDATE fn : transfer rewards to user, from rewardsVault
        REWARDS_VAULT.payRewards(onBehalfOf, unclaimedRewards);
    }

    // unstake all: tokens, nfts, rp  | can unstake anytime
    // refactor to do vault updates at the end, accounting for nft boost delta | else double calcs
    function unstakeAll(bytes32 vaultId, address onBehalfOf) external whenStarted whenNotPaused {
        require(vaultId > 0, "Invalid vaultId");

        // check if vault exists + cache vault & user's vault assets
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);

        // Update all distributions, their respective vault accounts, and user accounts for specified vault
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        // get user staked assets: old values for events
        uint256 stakedTokens = userVaultAssets.stakedTokens;
        uint256 stakedNfts = userVaultAssets.tokenIds.length;
        uint256 stakedRealmPoints = userVaultAssets.stakedRealmPoints;

        uint256 oldBoostedRealmPoints = userVaultAssets.boostedRealmPoints;
        uint256 oldBoostedStakedTokens = userVaultAssets.boostedStakedTokens;

        // check if user has non-zero holdings
        if(stakedTokens + stakedNfts + stakedRealmPoints == 0) revert Errors.UserHasNothingStaked(vaultId, onBehalfOf);
        
        //update token balances: user + vault
        if(stakedTokens > 0){

            // update stakedTokens
            vault.stakedTokens -= stakedTokens;
            vault.boostedStakedTokens -= userVaultAssets.boostedStakedTokens;

            delete userVaultAssets.stakedTokens;
            delete userVaultAssets.boostedStakedTokens;

            emit UnstakedMoca(onBehalfOf, vaultId, stakedTokens);       
        }

        //update rp balances: user + vault
        if(stakedRealmPoints > 0){

            // update stakedTokens
            vault.stakedRealmPoints -= stakedRealmPoints;
            vault.boostedRealmPoints -= userVaultAssets.boostedRealmPoints;

            delete userVaultAssets.stakedRealmPoints;
            delete userVaultAssets.boostedRealmPoints;
            
            // record free realm points
            userVaultAssets.realmPoints += stakedRealmPoints;

            //emit UnstakedMoca(onBehalfOf, vaultId, stakedTokens);       
        }

        //note: update multiplier/boost for unstaking of nfts
        if(stakedNfts > 0){

            // record unstake with registry
            NFT_REGISTRY.recordUnstake(onBehalfOf, userVaultAssets.tokenIds, vaultId);
            emit UnstakedMocaNft(onBehalfOf, vaultId, userVaultAssets.tokenIds);       

            // update stakedNfts
            vault.stakedNfts -= stakedNfts;            
            delete userVaultAssets.tokenIds;

            // recalc. boosted values
            uint256 boostFactorDelta = stakedNfts * NFT_MULTIPLIER;
            vault.totalBoostFactor -= boostFactorDelta;

            // recalc. boosted balances with new boost factor 
            if (vault.stakedTokens > 0) vault.boostedStakedTokens = (vault.stakedTokens * vault.totalBoostFactor) / 1e18;            
            if (vault.stakedRealmPoints > 0) vault.boostedRealmPoints = (vault.stakedRealmPoints * vault.totalBoostFactor) / 1e18;
        }

        // update storage: mappings 
        vaults[vaultId] = vault;
        usersVaultAssets[onBehalfOf][vaultId] = userVaultAssets;

        // update storage: global variables 
        totalStakedNfts -= stakedNfts;
        totalBoostedRealmPoints -= oldBoostedRealmPoints;
        totalBoostedStakedTokens -= oldBoostedStakedTokens;
    }

//-------------------------------internal-------------------------------------------

/*
    // update all active distributions: book prior rewards, based on prior alloc points 
    function _updateDistributionIndexes() internal {
        if(activeDistributions.length == 0) revert; // at least staking power should have been setup on deployment

        uint256 numOfDistributions = activeDistributions.length;

        for(uint256 i; i < numOfDistributions; ++i) {

            DataTypes.Distribution memory distribution = distributions[activeDistributions[i]];
            _updateDistributionIndex(distribution);

            // update storage
            distributions[activeDistributions[i]] = distribution;
        }
    }
*/

/*
    // update all vault accounts per active distribution, for specified vault
    function _updateVaultAccounts(bytes32 vaultId) internal {

        DataTypes.Vault memory vault = vaults[vaultId];

        // always > 0, staking power is setup on deployment
        uint256 numOfActiveVaults = activeDistributions.length;
        
        // update each vault account
        for (uint256 i; i < numOfActiveVaults; i++) {

            DataTypes.Distribution memory distribution_ = distributions[activeDistributions[i]];
            // get vault account for active distribution
            DataTypes.VaultData memory vaultAccount = vaultAccounts[vaultId][activeDistributions[i]];

            // get latest distributionIndex
            DataTypes.Distribution memory distribution = _updateDistributionIndex(distribution_);
            
            // vault already been updated by a prior txn; skip updating
            if(distribution.index == vaultAccount.index) continue;

            // If vault has ended, vaultIndex should not be updated, beyond the final update.
            if(block.timestamp >= vault.endTime) continue;

            // update vault rewards + fees
            uint256 accruedRewards; 
            uint256 accCreatorFee; 
            uint256 accTotalNftFee;
            uint256 accRealmPointsFee;

            // Calculate rewards based on distribution type (staking power or token rewards)
            uint256 stakedBalance = distribution.chainId == 0 ? vault.boostedRealmPoints : vault.boostedStakedTokens;
            accruedRewards = _calculateRewards(stakedBalance, distribution.index, vaultAccount.index);

            // calc. creator fees
            if(vault.creatorFeeFactor > 0) {
                accCreatorFee = (accruedRewards * vault.creatorFeeFactor) / distribution.TOKEN_PRECISION;
            }

            // nft fees accrued only if there were staked NFTs
            if(vault.stakedNfts > 0) {
                if(vault.nftFeeFactor > 0) {
                    accTotalNftFee = (accruedRewards * vault.nftFeeFactor) / distribution.TOKEN_PRECISION;

                    vaultAccount.nftIndex += (accTotalNftFee / vault.stakedNfts);              // nftIndex: rewardsAccPerNFT
                }
            }

            if(vault.realmPointsFeeFactor > 0) {
                accRealmPointsFee = (accruedRewards * vault.realmPointsFeeFactor) / distribution.TOKEN_PRECISION;
            } 
            
            // book rewards: total, Creator, NFT, RealmPoints
            vaultAccount.totalAccRewards += accruedRewards;
            vaultAccount.accCreatorRewards += accCreatorFee;
            vaultAccount.accNftStakingRewards += accTotalNftFee;
            vaultAccount.accRealmPointsRewards += accRealmPointsFee;

            // reference for users' to calc. rewards: rewards net of fees
            vaultAccount.rewardsAccPerUnitStaked += ((accruedRewards - accCreatorFee - accTotalNftFee - accRealmPointsFee) * TOKEN_PRECISION) / stakedBalance;

            // update vaultIndex
            vaultAccount.vaultIndex = distribution.index;

            // emit VaultIndexUpdated

            // update storage
            distributions[activeDistributions[i]] = distribution;     
            vaultAccounts[vaultId][activeDistributions[i]] = vaultAccount;   
        }   
    }
*/
    //
    function _updateDistributionIndex(DataTypes.Distribution memory distribution) internal return(DataTypes.Distribution memory) {
        
        // already updated: return
        if(distribution.lastUpdateTimeStamp == block.timestamp) return distribution;
        
        uint256 nextVaultIndex;
        uint256 currentTimestamp;
        uint256 emittedRewards;

        // staking power
        if(distribution.chainId == 0) {
            
            // staked RP is the base of Staking power rewards
            (nextDistributionIndex, currentTimestamp, emittedRewards) = _calculateDistributionIndex(distribution.index, distribution.emissionPerSecond, distribution.lastUpdateTimeStamp, totalBoostedRealmPoints, distribution.TOKEN_PRECISION);

        } else {

            // staked Moca is the base of token rewards
            (nextDistributionIndex, currentTimestamp, emittedRewards) = _calculateDistributionIndex(distribution.index, distribution.emissionPerSecond, distribution.lastUpdateTimeStamp, totalBoostedStakedTokens, distribution.TOKEN_PRECISION);
        }

        if(nextDistributionIndex != distribution.index) {
            
            // prev timestamp, oldIndex, newIndex: emit prev timestamp since you know the currentTimestamp as per txn time
            // emit VaultIndexUpdated(pool_.lastUpdateTimeStamp, pool_.index, nextPoolIndex); note: update event

            distribution.index = nextDistributionIndex;
            distribution.totalEmitted += emittedRewards; 
            distribution.lastUpdateTimeStamp = block.timestamp;
        }

        return distribution;
    }

    /**
     * @dev Calculates latest pool index. Pool index represents accRewardsPerAllocPoint since startTime.
     * @param currentDistributionIndex Latest reward index as per previous update
     * @param emissionPerSecond Reward tokens emitted per second (in wei)
     * @param lastUpdateTimestamp Time at which previous update occurred
     * @param totalBalance Total allocPoints of the pool 
     * @return nextPoolIndex: Updated pool index, 
               currentTimestamp: either lasUpdateTimestamp or block.timestamp, 
               emittedRewards: rewards emitted from lastUpdateTimestamp till now
     */
    function _calculateDistributionIndex(uint256 currentDistributionIndex, uint256 emissionPerSecond, uint256 lastUpdateTimestamp, uint256 totalBalance, uint256 distributionPrecision) internal view returns (uint256, uint256, uint256) {
        if (
            emissionPerSecond == 0                           // 0 emissions. no rewards setup.
            || totalBalance == 0                             // nothing has been staked
            || lastUpdateTimestamp == block.timestamp        // index already updated
            || lastUpdateTimestamp > endTime                 // distribution has ended
        ) {

            return (currentDistributionIndex, lastUpdateTimestamp, 0);                       
        }

        uint256 currentTimestamp;
        if(endTime > 0){
            currentTimestamp = block.timestamp > endTime ? endTime : block.timestamp;
        }
        else {
            currentTimestamp = block.timestamp;
        }

        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;
        
        uint256 emittedRewards = emissionPerSecond * timeDelta;

        //note: totalBalance is expressed 1e18. emittedRewards is variable as per distribution.TOKEN_PRECISION
        //note: paper the math for this 
        uint256 nextDistributionIndex = ((emittedRewards * 1E18) / distributionPrecision / totalBalance) + currentDistributionIndex;   

        //note: here on out the index should be denominated in 1E18 - applicable to MOCA,RP,SP
    
        return (nextDistributionIndex, currentTimestamp, emittedRewards);
    }


    // update specified vault account
    // returns updated vault account and updated distribution structs 
    function _updateVaultAccount(
        DataTypes.Vault memory vault, 
        DataTypes.VaultData memory vaultAccount, 
        DataTypes.Distribution memory distribution_) internal return(DataTypes.VaultAccount memory, DataTypes.Distribution memory) {

        // get latest distributionIndex
        DataTypes.Distribution memory distribution = _updateDistributionIndex(distribution_);
        
        // vault already been updated by a prior txn; skip updating
        if(distribution.index == vaultAccount.index) continue;

        // If vault has ended, vaultIndex should not be updated, beyond the final update.
        if(block.timestamp >= vault.endTime) continue;

        // update vault rewards + fees
        uint256 accruedRewards; 
        uint256 accCreatorFee; 
        uint256 accTotalNftFee;
        uint256 accRealmPointsFee;

        // calculate rewards owed to MOCA token stakers
        totalAccRewards = _calculateRewards(vault.stakedTokens, distribution.index, vaultAccount.index);

        // calc. creator fees
        if(vault.creatorFeeFactor > 0) {
            accCreatorFee = (totalAccRewards * vault.creatorFeeFactor) / 1E18;
        }

        // nft fees accrued only if there were staked NFTs
        if(vault.stakedNfts > 0) {
            if(vault.nftFeeFactor > 0) {

                accTotalNftFee = (totalAccRewards * vault.nftFeeFactor) / 1E18;
                vaultAccount.nftIndex += (accTotalNftFee / vault.stakedNfts);              // nftIndex: rewardsAccPerNFT
            }
        }

        // rp fees accrued only if there were staked RP 
        if(vault.stakedRealmPoints > 0) {
            if(vault.realmPointsFeeFactor > 0) {
                accRealmPointsFee = (totalAccRewards * vault.realmPointsFeeFactor) / 1E18;
                vaultAccount.rpIndex += (accRealmPointsFee / vault.stakedRealmPoints);              // rpIndex: rewardsAccPerRP
            }
        } 
        
        // book rewards: total, Creator, NFT, RealmPoints
        vaultAccount.totalAccRewards += totalAccRewards;
        vaultAccount.accCreatorRewards += accCreatorFee;
        vaultAccount.accNftStakingRewards += accTotalNftFee;
        vaultAccount.accRealmPointsRewards += accRealmPointsFee;

        // reference for moca staker's to calc. rewards net of fees
        // do division at the end again, instead of using the indexes to avoid rounding-down drift
        vaultAccount.rewardsAccPerUnitStaked += ((totalAccRewards - accCreatorFee - accTotalNftFee - accRealmPointsFee) * 1E18) / vault.stakedTokens;

        // update vaultIndex
        vaultAccount.vaultIndex = distribution.index;

        // emit VaultIndexUpdated    

        return (vaultAccount, distribution);
    }

    function _updateUserAccount(
        DataTypes.User memory user, DataTypes.UserAccount memory userAccount, 
        DataTypes.Vault memory vault, DataTypes.VaultData memory vaultAccount, DataTypes.Distribution memory distribution) internal returns (DataTypes.UserAccount memory, DataTypes.VaultAccount memory, DataTypes.Distribution memory)  {
        
        // get updated vaultAccount and distribution
        DataTypes.VaultData memory vaultAccount, DataTypes.Distribution memory distribution = _updateVaultAccount(vault, vaultAccount, distribution);

        uint256 newUserIndex = vaultAccount.rewardsAccPerUnitStaked;    // less of fees
        uint256 newUserNftIndex = vaultAccount.nftIndex;
        uint256 newUserRpIndex = vaultAccount.rpIndex;

        uint256 accruedRewards;
        if(userAccount.index != newUserIndex) { // if this index has not been updated, the subsequent ones would not have. check once here, no need repeat. 
            if(user.stakedTokens > 0) {
                // users whom staked tokens are eligible for rewards less of fees
                accruedRewards = _calculateRewards(user.stakedTokens, newUserIndex, userAccount.index);
                userAccount.accStakingRewards += accruedRewards;

                // emit RewardsAccrued(user, accruedRewards);
            }
        }

        uint256 userStakedNfts = user.tokenIds.length;
        if(userStakedNfts > 0) {

            // total accrued rewards from staking NFTs
            uint256 accNftStakingRewards = (newUserNftIndex - userAccount.nftIndex) * userStakedNfts;
            userAccount.accNftStakingRewards += accNftStakingRewards;

            //emit NftRewardsAccrued(user, accNftStakingRewards);
        }

        if(user.stakedRealmPoints > 0){
            
            // users whom staked RP are eligible for a portion of RP fees
            uint256 accRealmPointsRewards = (newUserRpIndex - userAccount.rpIndex) * user.stakedRealmPoints;
            userAccount.accRealmPointsRewards += accRealmPointsRewards;

            //emit something
        }

        // update user indexes
        userAccount.userIndex = newUserIndex;
        userAccount.userNftIndex = newUserNftIndex;
        userAccount.rpIndex = newUserRpIndex;

        // emit UserIndexesUpdated(user, vault.vaultId, newUserIndex, newUserNftIndex, userInfo.accStakingRewards);

        return (userAccount, vaultAccount, distribution);
    }

    /// called prior to affecting any state change to a user
    /// applies fees onto the vaultIndex to return the userIndex
    function _updateUserAccounts(address user, bytes32 vaultId, DataTypes.Vault memory vault, DataTypes.User memory userVaultAssets) internal {

        /** user -> vaultId (stake)
            - this changes the composition for both the user and vault
            - before booking the change we must update all vault and user accounts
            -- distr_0: distriData, vaultAccount, userAccount
            -- distr_1: distriData, vaultAccount, userAccount

            loop thru userAccounts -> vaultAccounts -> distri
         */

        // always > 0, staking power is setup on deployment
        uint256 numOfUserAccounts = activeDistributions.length;
        
        // update each user account, looping thru distributions
        for (uint256 i; i < numOfUserAccounts; i++) {
             
            uint256 distributionId = activeDistributions[i];   

            // get corresponding user+vault account for this active distribution 
            DataTypes.Distribution memory distribution = distributions[distributionId];
            DataTypes.VaultData memory vaultAccount = vaultAccounts[vaultId][distributionId];
            DataTypes.UserAccount memory userAccount = userAccounts[user][vaultId][distributionId];

            
            (DataTypes.UserAccount memory userAccount, DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _updateUserAccount(userVaultAssets, userAccount, vault, vaultAccount, distribution);

            //update storage: accounts and distributions
            distributions[distributionId] = distribution;     
            vaultAccounts[vaultId][distributionId] = vaultAccount;  
            userAccounts[user][vaultId][distributionId] = userAccount;
        }
 
    }

    // for calc. rewards from index deltas. assumes tt indexes are rebased to 1E18 precision
    function _calculateRewards(uint256 balance, uint256 currentIndex, uint256 priorIndex) internal pure returns (uint256) {
        return (balance * (currentIndex - priorIndex)) / 1E18;
    }


    ///@dev cache vault and user structs from storage to memory. checks that vault exists, else reverts.
    function _cache(bytes32 vaultId, address onBehalfOf) internal view returns(/*DataTypes.User memory*/, DataTypes.User memory, DataTypes.Vault memory) {
        
        // ensure vault exists
        DataTypes.Vault memory vault = vaults[vaultId];
        if(vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);

        // get global and vault level user data
        //DataTypes.User memory userGlobal = users[onBehalfOf];
        DataTypes.User memory userVaultAssets = usersVaultAssets[onBehalfOf][vaultId];

        return (/*userGlobal*/, userVaultAssets, vault);
    }

    ///@dev concat two uint256 arrays: [1,2,3],[4,5] -> [1,2,3,4,5]
    function _concatArrays(uint256[] memory arr1, uint256[] memory arr2) internal pure returns(uint256[] memory) {
        
        // create resulting arr
        uint256 len1 = arr1.length;
        uint256 len2 = arr2.length;
        uint256[] memory resArr = new uint256[](len1 + len2);
        
        uint256 i;
        for (; i < len1; i++) {
            resArr[i] = arr1[i];
        }
        
        uint256 j;
        while (j < len2) {
            resArr[i++] = arr2[j++];
        }

        return resArr;
    }

    ///@dev Generate a vaultId. keccak256 is cheaper than using a counter with a SSTORE, even accounting for eventual collision retries.
    function _generateVaultId(uint256 salt, address onBehalfOf) internal view returns (bytes32) {
        return bytes32(keccak256(abi.encode(onBehalfOf, block.timestamp, salt)));
    }


    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/


    modifier whenStarted() {

        require(block.timestamp >= startTime, "Not started");    

        _;
    }

/*
    modifier auth() {
        
        require(msg.sender == router || msg.sender == owner(), "Incorrect Caller");    

        _;
    }
*/
}