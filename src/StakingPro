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
import {IRealmPoints} from "./interfaces/IRealmPoints.sol";

contract StakingPro is Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    IERC20 public immutable STAKED_TOKEN;  
    IERC20 public immutable REWARD_TOKEN;

    INftRegistry public immutable NFT_REGISTRY;
    IRealmPoints public immutable REALM_POINTS;
    IRewardsVault public immutable REWARDS_VAULT;

    // token dp: 18 decimal places
    uint256 public constant TOKEN_PRECISION = 10 ** 18;  

    // times
    uint256 public immutable startTime;           // start time
    uint256 public endTime;                       // non-immutable: allow modification of staking period

    // pool emergency state
    bool public isFrozen;

    // pool data
    DataTypes.PoolAccounting public pool;

    // ------- [note: need to confirm values] -------------------

    // nft 
    uint256 public constant MAX_NFTS_PER_VAULT = 10; 
    uint256 public constant NFT_MULTIPLIER = 250;           // 2.5x multiplier 

//-------------------------------mappings-------------------------------------------
 
    // user can own one or more Vaults, each one with a bytes32 identifier
    mapping(bytes32 vaultId => DataTypes.Vault vault) public vaults;              
                   
    // Tracks unclaimed rewards accrued for each user: user -> vaultId -> userInfo
    mapping(address user => mapping (bytes32 vaultId => DataTypes.UserInfo userInfo)) public users;

    
//-------------------------------constructor-------------------------------------------

    constructor(
        IERC20 stakedToken, IERC20 rewardToken, address rewardsVault, 
        address registry, address realmPoints,
        uint256 startTime_, uint256 rewards, uint256 duration,
        string memory name, string memory symbol, address owner) payable Ownable(owner) {

        // sanity check input data: time, period, rewards
        require(startTime_ > block.timestamp, "Invalid startTime");
        require(rewards > 0, "Invalid rewards");

        // token assignments
        STAKED_TOKEN = stakedToken;
        REWARD_TOKEN = rewardToken;

        // interfaces: supporting contracts
        NFT_REGISTRY = INftRegistry(registry);              
        REALM_POINTS = IRealmPoints(realmPoints);
        REWARDS_VAULT = IRewardsVault(rewardsVault);    

        // instantiate data
        DataTypes.PoolAccounting memory pool_;

        // set startTime & pool.lastUpdateTimeStamp
        startTime = pool_.lastUpdateTimeStamp = startTime_;
        endTime = startTime_ + duration;   

        // sanity check: eps calculation
        pool_.emissisonPerSecond = rewards / duration;
        require(pool_.emissisonPerSecond > 0, "emissisonPerSecond = 0");

        // sanity check: rewards vault has sufficient tokens
        require(rewards <= REWARDS_VAULT.totalVaultRewards(), "Insufficient vault rewards");
        pool_.totalStakingRewards = rewards;

        // update storage
        pool = pool_;

        emit DistributionUpdated(pool_.emissisonPerSecond, endTime);
    }

//-------------------------------external-------------------------------------------


    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
      * @notice Creates empty vault. 
      * @dev 2 Nfts must be commited to create vault. Creation NFTs are locked to created pool
      * 
     */
    function createVault(address onBehalfOf, uint256[] calldata tokenIds, DataTypes.Fees calldata rewardTokenFees, DataTypes.Fees calldata stakingPowerFees) external whenStarted whenNotPaused {
        // must commit 2 unstaked NFTs to create vaults: these do not count towards stakedNFTs
        uint256 incomingNfts = tokenIds.length;
        if(incomingNfts != 2) revert Errors.IncorrectCreationNfts();
        
        for (uint256 i = 0; i < 2; i++) {

            (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds[i]);
            
            if(owner != onBehalfOf) revert Errors.IncorrectNftOwner(tokenIds[i]);
            if(nftVaultId != bytes32(0)) revert Errors.NftAlreadyStaked(tokenIds[i]);
        }

        //note: total fee cannot exceed 100%, which is defined as 1e18 = TOKEN_PRECISION
        // individual feeFactors can be 0
        uint256 rewardTokenTotalFeeFactor = rewardTokenFees.creatorFeeFactor + rewardTokenFees.nftFeeFactor + rewardTokenFees.realmPointFeeFactor;
        uint256 stakingPowerTotalFeeFactor = stakingPowerFees.creatorFeeFactor + stakingPowerFees.nftFeeFactor + stakingPowerFees.realmPointFeeFactor;

        if((rewardTokenTotalFeeFactor) > TOKEN_PRECISION) revert Errors.TotalFeeFactorExceeded();
        if((stakingPowerTotalFeeFactor) > TOKEN_PRECISION) revert Errors.TotalFeeFactorExceeded();

        // vaultId generation
        bytes32 vaultId;
        {
            uint256 salt = block.number - 1;
            vaultId = _generateVaultId(salt, onBehalfOf);
            while (vaults[vaultId].vaultId != bytes32(0)) vaultId = _generateVaultId(--salt, onBehalfOf);      // If vaultId exists, generate new random Id
        }

        // update poolIndex: book prior rewards, based on prior alloc points 
        (DataTypes.PoolAccounting memory pool_, ) = _updatePoolIndex();

        // build vault
        DataTypes.Vault memory vault; 
            vault.vaultId = vaultId;
            vault.creator = onBehalfOf;
            vault.startTime = block.timestamp; 
            vault.creationTokenIds = tokenIds;  //record creation Nfts
            
            // index
            vault.accounting.vaultIndex = pool_.index;
            //note: nftIndex

            // fees
            vault.accounting.rewardTokenFees = rewardTokenFees;
            vault.accounting.stakingPowerFees = stakingPowerFees;


        // update storage
        pool = pool_;
        vaults[vaultId] = vault;
        
        emit VaultCreated(onBehalfOf, vaultId); //emit totaLAllocPpoints updated?

        // record NFT commitment on registry contract
        NFT_REGISTRY.recordStake(onBehalfOf, tokenIds, vaultId);
    }  

    // no stkaing limit for moca
    function stakeTokens(bytes32 vaultId, address onBehalfOf, uint256 amount) external whenStarted whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(vaultId > 0, "Invalid vaultId");

        // check if vault exists + cache user & vault structs to memory
       (DataTypes.UserInfo memory userInfo_, DataTypes.Vault memory vault_) = _cache(vaultId, onBehalfOf);

        // update all indexes and book all prior rewards
       (DataTypes.UserInfo memory userInfo, DataTypes.Vault memory vault) = _updateUserIndexes(onBehalfOf, userInfo_, vault_);

        // calc. allocPoints
        uint256 incomingAllocPoints = (amount * vault.multiplier);

        // increment allocPoints
        vault.allocPoints += incomingAllocPoints;
        pool.totalAllocPoints += incomingAllocPoints;   //storage
        
        // increment stakedTokens: user, vault
        vault.stakedTokens += amount;
        userInfo.stakedTokens += amount;

        // update storage
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userInfo;

        emit StakedMoca(onBehalfOf, vaultId, amount);

        // note: how does staked moca boost staking power?
    
        // mint stkMOCA
        //_mint(onBehalfOf, amount);

        // grab MOCA
        STAKED_TOKEN.safeTransferFrom(onBehalfOf, address(this), amount);
    }

    // Note: reset NFT assoc via recordUnstake()
    // else users cannot switch nfts to the new pool.
    function stakeNfts(bytes32 vaultId, address onBehalfOf, uint256[] calldata tokenIds) external whenStarted whenNotPaused {
        uint256 incomingNfts = tokenIds.length;

        require(incomingNfts > 0 && incomingNfts < MAX_NFTS_PER_VAULT, "Invalid amount"); 
        require(vaultId > 0, "Invalid vaultId");

        // get vault + check if has been created
       (DataTypes.UserInfo memory userInfo_, DataTypes.Vault memory vault_) = _cache(vaultId, onBehalfOf);

        // update indexes and book all prior rewards
        (DataTypes.UserInfo memory userInfo, DataTypes.Vault memory vault) = _updateUserIndexes(onBehalfOf, userInfo_, vault_);

        //if(endTime <= block.timestamp) --> note: what to do when pool has reached endTime and not extended?         

        // sanity checks:nft staked amount cannot exceed limit
        if(vault.stakedNfts + incomingNfts > MAX_NFTS_PER_VAULT) revert Errors.NftStakingLimitExceeded(vaultId, vault.stakedNfts);
        
        // update user tokenIds
        userInfo.tokenIds = _concatArrays(userInfo.tokenIds, tokenIds);

        // update nft + multiplier
        vault.stakedNfts += incomingNfts;
        vault.multiplier += incomingNfts * NFT_MULTIPLIER;

        // cache
        uint256 oldMultiplier = vault.multiplier;
        uint256 oldAllocPoints = vault.allocPoints;

        // calc. new alloc points | there is only impact if vault has prior stakedTokens
        if(vault.stakedTokens > 0) {
            uint256 deltaAllocPoints = (vault.stakedTokens * vault.multiplier) - oldAllocPoints;

            // book 1st stake incentive | if no prior stake, no nft incentive
            if(vault.stakedNfts == 0) {
                userInfo.accNftStakingRewards = vault.accounting.accNftStakingRewards;
                emit NftRewardsAccrued(onBehalfOf, userInfo.accNftStakingRewards);
            }

            // update allocPoints
            vault.allocPoints += deltaAllocPoints;
            pool.totalAllocPoints += deltaAllocPoints;
        }
        
        // update storage
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userInfo;

        emit StakedMocaNft(onBehalfOf, vaultId, tokenIds);
        emit VaultMultiplierUpdated(vaultId, oldMultiplier, vault.multiplier);

        // record stake with registry
        NFT_REGISTRY.recordStake(onBehalfOf, tokenIds, vaultId);
    }

    // claim MocaTokens
    function claimRewards(bytes32 vaultId, address onBehalfOf) external whenStarted whenNotPaused {
        require(vaultId > 0, "Invalid vaultId");

        // get vault + check if has been created
       (DataTypes.UserInfo memory userInfo_, DataTypes.Vault memory vault_) = _cache(vaultId, onBehalfOf);

        // update indexes and book all prior rewards
        (DataTypes.UserInfo memory userInfo, DataTypes.Vault memory vault) = _updateUserIndexes(onBehalfOf, userInfo_, vault_);

        // update balances
        uint256 unclaimedRewards = userInfo.accStakingRewards - userInfo.claimedStakingRewards;
        userInfo.claimedStakingRewards += unclaimedRewards;
        vault.accounting.totalClaimedRewards += unclaimedRewards;

        //update storage
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userInfo;

        emit RewardsClaimed(vaultId, onBehalfOf, unclaimedRewards);

        // transfer rewards to user, from rewardsVault
        REWARDS_VAULT.payRewards(onBehalfOf, unclaimedRewards);
    }

    function claimFees(bytes32 vaultId, address onBehalfOf) external whenStarted whenNotPaused {
        require(vaultId > 0, "Invalid vaultId");

        // get vault + check if has been created
       (DataTypes.UserInfo memory userInfo_, DataTypes.Vault memory vault_) = _cache(vaultId, onBehalfOf);

        // update indexes and book all prior rewards
        (DataTypes.UserInfo memory userInfo, DataTypes.Vault memory vault) = _updateUserIndexes(onBehalfOf, userInfo_, vault_);

        uint256 totalUnclaimedRewards;

        // collect creator fees
        if(vault.creator == onBehalfOf) {
            uint256 unclaimedCreatorRewards = (vault.accounting.accCreatorRewards - userInfo.claimedCreatorRewards);
            
            if(unclaimedCreatorRewards > 0){
                totalUnclaimedRewards += unclaimedCreatorRewards;

                // update user balances
                userInfo.claimedCreatorRewards += unclaimedCreatorRewards;          
                emit CreatorRewardsClaimed(vaultId, onBehalfOf, unclaimedCreatorRewards);
            }
        }
        
        // collect NFT fees
        if(userInfo.accNftStakingRewards > 0) {    
            uint256 unclaimedNftRewards = (userInfo.accNftStakingRewards - userInfo.claimedNftRewards);
            
            if(unclaimedNftRewards > 0){
                totalUnclaimedRewards += unclaimedNftRewards;
                
                // update user balances
                userInfo.claimedNftRewards += unclaimedNftRewards;
                emit NftRewardsClaimed(vaultId, onBehalfOf, unclaimedNftRewards);
            }
        }

        // collect RealmPoints Fees
        // note:
        
        // update vault balances
        vault.accounting.totalClaimedRewards += totalUnclaimedRewards;

        // update storage
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userInfo;

        // transfer rewards to user, from rewardsVault
        REWARDS_VAULT.payRewards(onBehalfOf, totalUnclaimedRewards);
    }     

    // untake mocaTokens and Nfts. rp cannot be unstaked
    function unstakeAll(bytes32 vaultId, address onBehalfOf) external whenStarted whenNotPaused {
        require(vaultId > 0, "Invalid vaultId");

        // get vault + check if has been created
       (DataTypes.UserInfo memory userInfo_, DataTypes.Vault memory vault_) = _cache(vaultId, onBehalfOf);

        // update indexes and book all prior rewards
        (DataTypes.UserInfo memory userInfo, DataTypes.Vault memory vault) = _updateUserIndexes(onBehalfOf, userInfo_, vault_);

        // get user holdings
        uint256 stakedNfts = userInfo.tokenIds.length;
        uint256 stakedTokens = userInfo.stakedTokens;

        // check if vault has matured + user has non-zero holdings
        //note: what to do when hitting pool end Time? if(block.timestamp < vault.endTime) revert Errors.VaultNotMatured(vaultId);
        if(stakedTokens == 0 && stakedNfts == 0) revert Errors.UserHasNothingStaked(vaultId, onBehalfOf); 

        //note: reset multiplier? or leave it for record keeping?
        // vault.multiplier = 1;

        //update balances: user + vault
        if(stakedNfts > 0){
            
            // record unstake with registry
            NFT_REGISTRY.recordUnstake(onBehalfOf, userInfo.tokenIds, vaultId);
            emit UnstakedMocaNft(onBehalfOf, vaultId, userInfo.tokenIds);       

            // update vault and user
            vault.stakedNfts -= stakedNfts;
            delete userInfo.tokenIds;
        }

        if(stakedTokens > 0){
            // update stakedTokens
            vault.stakedTokens -= userInfo.stakedTokens;
            delete userInfo.stakedTokens;
            
            // burn stkMOCA
            //_burn(onBehalfOf, stakedTokens);

            emit UnstakedMoca(onBehalfOf, vaultId, stakedTokens);       
        }

        // update storage
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userInfo;

        // return principal MOCA
        if(stakedTokens > 0) STAKED_TOKEN.safeTransfer(onBehalfOf, stakedTokens); 
    }

    ///@notice Only allowed to reduce the creator fee factor
    function updateCreatorFee(bytes32 vaultId, address onBehalfOf, uint256 newCreatorFeeFactor) external whenStarted whenNotPaused {}


    ///@notice Only allowed to increase the nft fee factor
    ///@dev Creator decrements the totalNftFeeFactor, which is dividied up btw the various nft stakers
    //TODO
    function updateNftFee(bytes32 vaultId, address onBehalfOf, uint256 newNftFeeFactor) external whenStarted whenNotPaused {}
    // TODO
    function updateRPFee(bytes32 vaultId, address onBehalfOf, uint256 newRpFeeFactor) external whenStarted whenNotPaused {}



    //TODO: cooldown 7 days
    function closeVault(bytes32 vaultId) external whenStarted whenNotPaused {}

    //TODO: migrate to another pool
    function migrateAssets(bytes32 vaultId, address onBehalfOf, uint256 amount) external whenStarted whenNotPaused {}
        function migrateRealmPoints(bytes32 vaultId, address onBehalfOf, uint256 amount) external whenStarted whenNotPaused {}
        function migrateNfts(bytes32 vaultId, address onBehalfOf, uint256 amount) external whenStarted whenNotPaused {}  
        function migrateMoca(bytes32 vaultId, address onBehalfOf, uint256 amount) external whenStarted whenNotPaused {}


//-------------------------------internal-------------------------------------------

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/


    /**
     * @dev Check if pool index is in need of updating, to bring it in-line with present time
     * @return poolAccounting struct, 
               currentTimestamp: either lasUpdateTimestamp or block.timestamp
     */
    function _updatePoolIndex() internal returns (DataTypes.PoolAccounting memory, uint256) {
        // cache
        DataTypes.PoolAccounting memory pool_ = pool;
        
        // already updated: return
        if(block.timestamp == pool_.lastUpdateTimeStamp) {
            return (pool_, pool_.lastUpdateTimeStamp);
        }
        
        // totalBalance = totalAllocPoints (boosted balances)
        (uint256 nextPoolIndex, uint256 currentTimestamp, uint256 emittedRewards) = _calculatePoolIndex(pool_.index, pool_.emissisonPerSecond, pool_.lastUpdateTimeStamp, pool.totalAllocPoints);

        if(nextPoolIndex != pool_.index) {
            
            // prev timestamp, oldIndex, newIndex: emit prev timestamp since you know the currentTimestamp as per txn time
            emit PoolIndexUpdated(pool_.lastUpdateTimeStamp, pool_.index, nextPoolIndex);

            pool_.index = nextPoolIndex;
            pool_.rewardsEmitted += emittedRewards; 
            pool_.lastUpdateTimeStamp = block.timestamp;
        }

        // update storage
        pool = pool_;

        return (pool_, currentTimestamp);
    }


    /**
     * @dev Calculates latest pool index. Pool index represents accRewardsPerAllocPoint since startTime.
     * @param currentPoolIndex Latest pool index as per previous update
     * @param emissionPerSecond Reward tokens emitted per second (in wei)
     * @param lastUpdateTimestamp Time at which previous update occured
     * @param totalBalance Total allocPoints of the pool 
     * @return nextPoolIndex: Updated pool index, 
               currentTimestamp: either lasUpdateTimestamp or block.timestamp, 
               emittedRewards: rewards emitted from lastUpdateTimestamp till now
     */
    function _calculatePoolIndex(uint256 currentPoolIndex, uint256 emissionPerSecond, uint256 lastUpdateTimestamp, uint256 totalBalance) internal view returns (uint256, uint256, uint256) {
        if (
            emissionPerSecond == 0                           // 0 emissions. no rewards setup. 
            || totalBalance == 0                             // nothing has been staked
            || lastUpdateTimestamp == block.timestamp        // assetIndex already updated
            || lastUpdateTimestamp > endTime                 // distribution has ended
        ) {

            return (currentPoolIndex, lastUpdateTimestamp, 0);                       
        }

        uint256 currentTimestamp = block.timestamp > endTime ? endTime : block.timestamp;
        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;
        
        uint256 emittedRewards = emissionPerSecond * timeDelta;

        uint256 nextPoolIndex = ((emittedRewards * TOKEN_PRECISION) / totalBalance) + currentPoolIndex;
    
        return (nextPoolIndex, currentTimestamp, emittedRewards);
    }

    ///@dev called prior to affecting any state change to a vault
    ///     book prior rewards, update vaultIndex + totalAccRewards
    ///     does not update vault storage
    function _updateVaultIndex(DataTypes.Vault memory vault) internal returns(DataTypes.Vault memory) {
        //1. called on vault state-change: stake, claimRewards, etc
        //2. book prior rewards, before affecting state change
        //3. vaulIndex = newPoolIndex

        // get latest poolIndex
        (DataTypes.PoolAccounting memory pool_, uint256 latestPoolTimestamp) = _updatePoolIndex();

        // vault already been updated by a prior txn; exit early
        if(pool_.index == vault.accounting.vaultIndex) return vault;

        // If vault has matured, vaultIndex should not be updated, beyond the final update.
        // vault.allocPoints == 0, indicates that vault has matured and the final update has been done
        // no further updates should be made; exit early
        if(vault.allocPoints == 0) return vault;

        // update vault rewards + fees
        uint256 accruedRewards; 
        uint256 accCreatorFee; 
        uint256 accTotalNftFee;
        uint256 accRealmPointsFee;
        if (vault.stakedTokens > 0) {       // a vault can only accrue rewards when there are tokens stake

            // calc. prior unbooked token rewards 
            accruedRewards = _calculateRewards(vault.allocPoints, pool_.index, vault.accounting.vaultIndex);

            // calc. reward token fees
            if(vault.accounting.rewardTokenFees.creatorFeeFactor > 0) {
                accCreatorFee = (accruedRewards * vault.accounting.rewardTokenFees.creatorFeeFactor) / TOKEN_PRECISION;
            }            
            // nft fees accrued only if there were staked NFTs
            if(vault.stakedNfts > 0) {
                if(vault.accounting.rewardTokenFees.nftFeeFactor > 0) {
                    accTotalNftFee = (accruedRewards * vault.accounting.rewardTokenFees.nftFeeFactor) / TOKEN_PRECISION;  

                    vault.accounting.vaultNftIndex += (accTotalNftFee / vault.stakedNfts);              // nftIndex: rewardsAccPerNFT
                }
            }
            if(vault.accounting.rewardTokenFees.realmPointFeeFactor > 0) {
                accRealmPointsFee = (accruedRewards * vault.accounting.rewardTokenFees.realmPointFeeFactor) / TOKEN_PRECISION;
    
            } 

            // book rewards: total, Creator, NFT, RealmPoints
            vault.accounting.totalAccRewards += accruedRewards;
            vault.accounting.accCreatorRewards += accCreatorFee;
            vault.accounting.accNftStakingRewards += accTotalNftFee;
            vault.accounting.accRealmPointsRewards += accRealmPointsFee;

            // reference for users' to calc. rewards: rewards nett of fees
            vault.accounting.rewardsAccPerToken += ((accruedRewards - accCreatorFee - accTotalNftFee - accRealmPointsFee) * TOKEN_PRECISION) / vault.stakedTokens;
        }

        // update vaultIndex
        vault.accounting.vaultIndex = pool_.index;

        emit VaultIndexUpdated(vault.vaultId, vault.accounting.vaultIndex, vault.accounting.totalAccRewards);

        return vault;
    }

    ///@dev called prior to affecting any state change to a user
    ///@dev applies fees onto the vaulIndex to return the userIndex
    function _updateUserIndexes(address user, DataTypes.UserInfo memory userInfo, DataTypes.Vault memory vault_) internal returns (DataTypes.UserInfo memory, DataTypes.Vault memory) {

        // get latest vaultIndex + vaultNftIndex
        DataTypes.Vault memory vault = _updateVaultIndex(vault_);
        
        uint256 newUserIndex = vault.accounting.rewardsAccPerToken;
        uint256 newUserNftIndex = vault.accounting.vaultNftIndex;
        
        uint256 accruedRewards;
        if(userInfo.userIndex != newUserIndex) {
            if(userInfo.stakedTokens > 0) {
                
                // rewards from staking MOCA
                accruedRewards = _calculateRewards(userInfo.stakedTokens, newUserIndex, userInfo.userIndex);
                userInfo.accStakingRewards += accruedRewards;

                emit RewardsAccrued(user, accruedRewards);
            }
        }

        uint256 userStakedNfts = userInfo.tokenIds.length;
        if(userStakedNfts > 0) {
            if(userInfo.userNftIndex != newUserNftIndex){

                // total accrued rewards from staking NFTs
                uint256 accNftStakingRewards = (newUserNftIndex - userInfo.userNftIndex) * userStakedNfts;
                userInfo.accNftStakingRewards += accNftStakingRewards;
                emit NftRewardsAccrued(user, accNftStakingRewards);
            }
        }

        //update userIndex
        userInfo.userIndex = newUserIndex;
        userInfo.userNftIndex = newUserNftIndex;
        
        emit UserIndexesUpdated(user, vault.vaultId, newUserIndex, newUserNftIndex, userInfo.accStakingRewards);

        return (userInfo, vault);
    }


    function _calculateRewards(uint256 balance, uint256 currentIndex, uint256 priorIndex) internal pure returns (uint256) {
        return (balance * (currentIndex - priorIndex)) / TOKEN_PRECISION;
    }

    ///@dev cache vault and user structs from storage to memory. checks that vault exists, else reverts.
    function _cache(bytes32 vaultId, address onBehalfOf) internal view returns(DataTypes.UserInfo memory, DataTypes.Vault memory) {
        
        // ensure vault exists
        DataTypes.Vault memory vault = vaults[vaultId];
        if(vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);

        // get userInfo for said vault
        DataTypes.UserInfo memory userInfo = users[onBehalfOf][vaultId];

        return (userInfo, vault);
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


//-------------------------------pool management-------------------------------------------

    /*//////////////////////////////////////////////////////////////
                            POOL MANAGEMENT
    //////////////////////////////////////////////////////////////*/


    /**
     * @notice To increase the duration of staking period and/or the rewards emitted
     * @dev Can increase rewards, duration MAY be extended. cannot reduce.
     * @param amount Amount of tokens by which to increase rewards. Accepts 0 value.
     * @param duration Amount of seconds by which to increase duration. Accepts 0 value.
     */
    function updateEmission(uint256 amount, uint256 duration) external onlyOwner {
        // either amount or duration could be 0; but not both
        if(amount == 0 && duration == 0) revert Errors.InvalidEmissionParameters();

        // ensure staking has not ended
        uint256 endTime_ = endTime;
        require(block.timestamp < endTime_, "Staking ended");

        // close the books
        (DataTypes.PoolAccounting memory pool_, ) = _updatePoolIndex();

        // updated values: amount could be 0 
        uint256 unemittedRewards = pool_.totalStakingRewards - pool_.rewardsEmitted;
        unemittedRewards += amount;
        require(unemittedRewards > 0, "Updated rewards: 0");
        
        // updated values: duration could be 0
        uint256 newDurationLeft = endTime_ + duration - block.timestamp;
        require(newDurationLeft > 0, "Updated duration: 0");
        
        // recalc: eps, endTime
        pool_.emissisonPerSecond = unemittedRewards / newDurationLeft;
        require(pool_.emissisonPerSecond > 0, "Updated EPS: 0");
        
        uint256 newEndTime = endTime_ + duration;

        // update storage
        pool = pool_;
        endTime = newEndTime;

        emit DistributionUpdated(pool_.emissisonPerSecond, newEndTime);
    }


    /**
     * @notice Pause pool
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause pool
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice To freeze the pool in the event of something untoward occuring
     * @dev Only callable from a paused state, affirming that staking should not resume
     *      Nothing to be updated. Freeze as is.
            Enables emergencyExit() to be called.
     */
    function freeze() external whenPaused onlyOwner {
        require(isFrozen == false, "Pool is frozen");
        
        isFrozen = true;

        emit PoolFrozen(block.timestamp);
    }  


    /*//////////////////////////////////////////////////////////////
                                RECOVER
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice For users to recover their principal assets in a black swan event
     * @dev Rewards and fees are not withdrawn; indexes are not updated
     * @param vaultId Address of token contract
     * @param onBehalfOf Recepient of tokens
     */
    function emergencyExit(bytes32 vaultId, address onBehalfOf) external whenStarted whenPaused onlyOwner {
        require(isFrozen, "Pool not frozen");
        require(vaultId > 0, "Invalid vaultId");

        // get vault + check if has been created
       (DataTypes.UserInfo memory userInfo, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);

        // check user has non-zero holdings
        uint256 stakedNfts = userInfo.tokenIds.length;
        uint256 stakedTokens = userInfo.stakedTokens;       
        if(stakedNfts == 0 && stakedTokens == 0) revert Errors.UserHasNothingStaked(vaultId, onBehalfOf);
       
        // update balances: user + vault
        if(stakedNfts > 0){

            // record unstake with registry, else users cannot switch nfts to the new pool
            NFT_REGISTRY.recordUnstake(onBehalfOf, userInfo.tokenIds, vaultId);
            emit UnstakedMocaNft(onBehalfOf, vaultId, userInfo.tokenIds);       

            // update vault and user
            vault.stakedNfts -= stakedNfts;
            delete userInfo.tokenIds;
        }

        if(stakedTokens > 0){

            vault.stakedTokens -= stakedTokens;
            delete userInfo.stakedTokens;
            
            // burn stkMOCA
            //_burn(onBehalfOf, stakedTokens);

            emit UnstakedMoca(onBehalfOf, vaultId, stakedTokens);       
        }

        /**
            Note:
            we do not zero out or decrement the following values: 
                1. vault.allocPoints 
                2. vault.multiplier
                3. pool.totalAllocPoints
            These values are retained to preserve state history at time of failure.
            This can serve as useful reference during post-mortem and potentially assist with any remediative actions.
         */

        // update storage 
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userInfo;

        // return principal stake
        if(stakedTokens > 0) STAKED_TOKEN.safeTransfer(onBehalfOf, stakedTokens); 
    }


    /**  NOTE: Consider dropping to avoid admin abuse
     * @notice Recover random tokens accidentally sent to the vault
     * @param tokenAddress Address of token contract
     * @param receiver Recepient of tokens
     * @param amount Amount to retrieve
     */
    function recoverERC20(address tokenAddress, address receiver, uint256 amount) external onlyOwner {
        require(tokenAddress != address(STAKED_TOKEN), "StakedToken: Not allowed");
        require(tokenAddress != address(REWARD_TOKEN), "RewardToken: Not allowed");

        emit RecoveredTokens(tokenAddress, receiver, amount);

        IERC20(tokenAddress).safeTransfer(receiver, amount);
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
