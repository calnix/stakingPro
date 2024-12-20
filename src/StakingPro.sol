// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import './Events.sol';
import {Errors} from './Errors.sol';
import {DataTypes} from './DataTypes.sol';

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

// interfaces
import {INftRegistry} from "./interfaces/INftRegistry.sol";
import {IRewardsVault} from "./interfaces/IRewardsVault.sol";

contract StakingPro is EIP712, Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    IERC20 public immutable STAKED_TOKEN;  
    INftRegistry public immutable NFT_REGISTRY;
    address public immutable STORED_SIGNER; // can this be immutable? 
    
    IRewardsVault public REWARDS_VAULT;

    // period
    uint256 public immutable startTime; // can start arbitrarily after deployment
    uint256 public endTime;             // if we need to end 

    // staked assets
    uint256 public totalStakedNfts;
    uint256 public totalStakedTokens;
    uint256 public totalStakedRealmPoints;

    // boosted balances
    uint256 public totalBoostedRealmPoints;
    uint256 public totalBoostedStakedTokens;

    // pool emergency state
    bool public isFrozen;

    uint256 public NFT_MULTIPLIER;                     // 10% = 1000/10_000 = 1000/PERCENTAGE_BASE 
    uint256 public constant PRECISION_BASE = 10_000;   // feeFactors & nft multiplier expressed in 2dp precision (XX.yy%)

    // creation nft requirement
    uint256 public CREATION_NFTS_REQUIRED;
    uint256 public VAULT_COOLDOWN_DURATION;
    
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
    uint256 public completedDistributions;  // note: when does this get updated?

    struct StakeRp {
        address user;
        uint256 vaultId;
        uint256 amount;
        uint256 expiry;
    }

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

    // global tracking of user assets note:consider removal
    //mapping(address user => DataTypes.User userGlobalAssets) public usersGlobal;

    // user's assets per vault
    mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) public users;

    // for independent reward distribution tracking              
    mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) public vaultAccounts;

    // rewards accrued per user, per distribution
    mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) public userAccounts;

    // replay attack: 1 is true, 0 is false
    mapping(bytes32 sig => uint256 executed) public executedSignatures;


//-------------------------------constructor------------------------------------------

    constructor(address registry, uint256 startTime_, uint256 nftMultiplier, uint256 creationNftsRequired, uint256 vaultCoolDownDuration,
        address owner, string memory name, string memory version) payable EIP712(name, version) Ownable(owner) {

        // sanity check input data: time, period, rewards
        require(owner > address(0), "Zero address");
        require(startTime_ > block.timestamp, "Invalid startTime");

        // interfaces: supporting contracts
        NFT_REGISTRY = INftRegistry(registry);              

        // set stakingPro startTime 
        startTime = startTime_;

        // storage vars
        NFT_MULTIPLIER = nftMultiplier;
        CREATION_NFTS_REQUIRED = creationNftsRequired;
        VAULT_COOLDOWN_DURATION = vaultCoolDownDuration;
    }


//-------------------------------external---------------------------------------------

    /**
      * @notice Creates empty vault
      * @dev Nfts must be committed to create vault. Creation NFTs are locked to create vault
     */
    function createVault(uint256[] calldata tokenIds, DataTypes.Fees calldata fees) external whenStarted whenNotPaused {
        address onBehalfOf = msg.sender;

        // update poolIndex: book prior rewards, based on prior alloc points 
        // _updateDistributionIndexes(); note: empty container. need to update?

        // must commit unstaked NFTs to create vaults: these do not count towards stakedNFTs
        uint256 incomingNfts = tokenIds.length;
        if(incomingNfts != CREATION_NFTS_REQUIRED) revert Errors.IncorrectCreationNfts();
        
        for (uint256 i; i < CREATION_NFTS_REQUIRED; i++) {

            (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds[i]);   // note: add batch fn to registry to check ownership
            
            if(owner != onBehalfOf) revert Errors.IncorrectNftOwner(tokenIds[i]);
            if(nftVaultId != bytes32(0)) revert Errors.NftAlreadyStaked(tokenIds[i]);
        }

        //note: MOCA stakers must receive ≥50% of all rewards
        uint256 totalFeeFactor = fees.nftFeeFactor + fees.creatorFeeFactor + fees.realmPointsFeeFactor;
        if(totalFeeFactor > 5000) revert Errors.TotalFeeFactorExceeded();     // 50% = 5000/10_000 = 5000/PRECISION_BASE

        // vaultId generation
        bytes32 vaultId;
        {
            uint256 salt = block.number - 1;
            vaultId = _generateVaultId(salt, onBehalfOf);
            while (vaults[vaultId].creator != address(0)) vaultId = _generateVaultId(--salt, onBehalfOf);      // If vaultId exists, generate new random Id
        }

        // build vault
        DataTypes.Vault memory vault; 
            //vault.vaultId = vaultId;
            vault.creator = onBehalfOf;
            vault.creationTokenIds = tokenIds;  
            
            vault.startTime = block.timestamp; 

            // fees
            vault.nftFeeFactor = fees.nftFeeFactor;
            vault.creatorFeeFactor = fees.creatorFeeFactor;
            vault.realmPointsFeeFactor = fees.realmPointsFeeFactor;
            
            // boost factor: Initialize to 100%, "1"
            vault.totalBoostFactor = PRECISION_BASE; 

        // update storage
        vaults[vaultId] = vault;

        //emit VaultCreated(onBehalfOf, vaultId); 

        // record NFT commitment on registry contract
        //NFT_REGISTRY.recordStake(onBehalfOf, tokenIds, vaultId);
    }  

    // no staking limits on staking assets
    function stakeTokens(bytes32 vaultId, uint256 amount) external whenStarted whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(vaultId > 0, "Invalid vaultId");
 
        address onBehalfOf = msg.sender;

        // check if vault exists + cache vault & user's vault assets
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);
     
        // check if vault has ended
        if(vault.endTime <= block.timestamp) revert Errors.VaultEnded(vaultId, vault.endTime);

        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        // calc. boostedStakedTokens
        uint256 incomingBoostedStakedTokens = (amount * vault.totalBoostFactor) / PRECISION_BASE;
        
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
        users[onBehalfOf][vaultId] = userVaultAssets;

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

        // check if vault has ended
        if(vault.endTime <= block.timestamp) revert Errors.VaultEnded(vaultId, vault.endTime);


        // Update all distributions, their respective vault accounts, and user accounts for specified vault
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        //if(endTime <= block.timestamp) --> note: what to do when pool has reached endTime and not extended?         

        // cache
        uint256 oldBoostedRealmPoints = vault.boostedRealmPoints;
        uint256 oldBoostedStakedTokens = vault.boostedStakedTokens;

        // update: vault's nfts 
        vault.stakedNfts += incomingNfts;
               
        // update boost factor: 
        uint256 boostFactorDelta = incomingNfts * NFT_MULTIPLIER;
        vault.totalBoostFactor += boostFactorDelta;     // totalBoostFactor begins frm PRECISION_BASE -> expressed as 1.XXX; 

        // recalc. boosted balances with new boost factor 
        if (vault.stakedTokens > 0) vault.boostedStakedTokens = (vault.stakedTokens * vault.totalBoostFactor) / PRECISION_BASE;            
        if (vault.stakedRealmPoints > 0) vault.boostedRealmPoints = (vault.stakedRealmPoints * vault.totalBoostFactor) / PRECISION_BASE;

        // update: user's tokenIds + boostedBalances
        userVaultAssets.tokenIds = _concatArrays(userVaultAssets.tokenIds, tokenIds);   //note: what does concat an empty arr do -- on first instance?
        userVaultAssets.boostedStakedTokens = (userVaultAssets.stakedTokens * vault.totalBoostFactor) / PRECISION_BASE;  
        userVaultAssets.boostedRealmPoints = (userVaultAssets.stakedRealmPoints * vault.totalBoostFactor) / PRECISION_BASE;

        // update storage: mappings 
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userVaultAssets;

        // update storage: global variables 
        totalStakedNfts += incomingNfts;
        totalBoostedRealmPoints += (vault.boostedRealmPoints - oldBoostedRealmPoints);
        totalBoostedStakedTokens += (vault.boostedStakedTokens - oldBoostedStakedTokens);

        emit StakedMocaNft(onBehalfOf, vaultId, tokenIds);
        //emit VaultMultiplierUpdated(vaultId, oldMultiplier, vault.multiplier);

        // record stake with registry
        //NFT_REGISTRY.recordStake(onBehalfOf, tokenIds, vaultId);
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
        vaultAccounts[vaultId][distributionId] = vaultAccount;
        userAccounts[onBehalfOf][vaultId][distributionId] = userAccount;

        // emit RewardsClaimed(vaultId, onBehalfOf, unclaimedRewards);

        // note: UPDATE fn : transfer rewards to user, from rewardsVault
        REWARDS_VAULT.payRewards(distributionId, onBehalfOf, unclaimedRewards);
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
            //NFT_REGISTRY.recordUnstake(onBehalfOf, userVaultAssets.tokenIds, vaultId);
            emit UnstakedMocaNft(onBehalfOf, vaultId, userVaultAssets.tokenIds);       

            // update stakedNfts
            vault.stakedNfts -= stakedNfts;            
            delete userVaultAssets.tokenIds;

            // recalc. boosted values
            uint256 boostFactorDelta = stakedNfts * NFT_MULTIPLIER;
            vault.totalBoostFactor -= boostFactorDelta;

            // update vault boosted balances w/ new boost factor 
            if (vault.stakedTokens > 0) vault.boostedStakedTokens = (vault.stakedTokens * vault.totalBoostFactor) / PRECISION_BASE;            
            if (vault.stakedRealmPoints > 0) vault.boostedRealmPoints = (vault.stakedRealmPoints * vault.totalBoostFactor) / PRECISION_BASE;
        }

        // update storage: mappings 
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userVaultAssets;

        // update storage: global variables 
        totalStakedNfts -= stakedNfts;
        totalBoostedRealmPoints -= oldBoostedRealmPoints;
        totalBoostedStakedTokens -= oldBoostedStakedTokens;
    }

    ///@notice Creator only allowed to reduce the creator fee factor, to increase the others 
    function updateVaultFees(bytes32 vaultId, address onBehalfOf, DataTypes.Fees calldata fees) external whenStarted whenNotPaused {
        require(vaultId > 0, "Invalid vaultId");
        
        // check if vault exists + cache vault & user's vault assets
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);

        // Update all distributions, their respective vault accounts, and user accounts for specified vault
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        // check vault: not ended + user must be creator 
        if(vault.endTime <= block.timestamp) revert Errors.VaultEnded(vaultId, vault.endTime);
        if(vault.creator != onBehalfOf) revert Errors.UserIsNotVaultCreator(vaultId, onBehalfOf);
        
        // incoming creatorFeeFactor must be lower than current
        if(fees.creatorFeeFactor > vault.creatorFeeFactor) revert Errors.CreatorFeeCanOnlyBeDecreased(vaultId);
        
        // new fee compositions must total to 100%
        uint256 totalFeeFactor = fees.nftFeeFactor + fees.creatorFeeFactor + fees.realmPointsFeeFactor;
        if(totalFeeFactor > 5000) revert Errors.TotalFeeFactorExceeded();     // 50% = 5000/10_000 = 5000/PRECISION_BASE

        // update fees
        vault.nftFeeFactor = fees.nftFeeFactor;
        vault.creatorFeeFactor = fees.creatorFeeFactor;
        vault.realmPointsFeeFactor = fees.realmPointsFeeFactor;
        
        // update storage: mappings 
        vaults[vaultId] = vault;

        // emit diff event
        //emit CreatorFeeFactorUpdated(vaultId, vault.accounting.creatorFeeFactor, newCreatorFeeFactor);
    }

    // cooldown 
    function activateCooldown(bytes32 vaultId) external whenStarted whenNotPaused {
        require(vaultId > 0, "Invalid vaultId");

        // check if vault exists + cache vault & user's vault assets
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, msg.sender);

        // Update all distributions, their respective vault accounts, and user accounts for specified vault
        _updateUserAccounts(msg.sender, vaultId, vault, userVaultAssets);

        // is it ended?
        if(vault.endTime > 0) revert Errors.VaultCooldownInitiated();

        // set endTime       
        vault.endTime = block.timestamp + VAULT_COOLDOWN_DURATION;

        // if zero cooldown, remove vault from circulation immediately 
        if(VAULT_COOLDOWN_DURATION == 0) {
            
            // decrement state vars
            
            totalStakedNfts -= vault.stakedNfts;
            totalStakedTokens -= vault.stakedTokens;
            totalStakedRealmPoints -= vault.stakedRealmPoints;

            totalBoostedRealmPoints -= vault.boostedRealmPoints;
            totalBoostedStakedTokens -= vault.boostedStakedTokens;
        }

        // emit
    }

    // cooldown. note: may want to flip the loop order
    // ch
    function endVaults(bytes32[] calldata vaultIds) external whenStarted whenNotPaused {
        uint256 numOfVaults = vaultIds.length;
        require(numOfVaults > 0, "Invalid array");

        uint256 numOfDistributions = activeDistributions.length; // always >= 1; staking power

        for(uint256 i; i < numOfVaults; ++i) {

            bytes32 vaultId = vaultIds[i];
            DataTypes.Vault memory vault = vaults[vaultId];

            // Update vault account for each active distribution
            for(uint256 j; j < numOfDistributions; ++j) {

                uint256 distributionId = activeDistributions[j];

                DataTypes.Distribution memory distribution_ = distributions[distributionId];
                DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[vaultId][distributionId];

                // returns memory structs
                (DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _updateVaultAccount(vault, vaultAccount_, distribution_);

                // Update storage
                vaultAccounts[vaultId][distributionId] = vaultAccount;
                if(distribution.lastUpdateTimeStamp < distribution_.lastUpdateTimeStamp){
                    distributions[distributionId] = distribution;
                }
            }
        }

        // emit

    }

    function migrateVaults(bytes32 oldVaultId, bytes32 newVaultId) external whenStarted whenNotPaused {
        require(oldVaultId > 0, "Invalid vaultId");
        require(newVaultId > 0, "Invalid vaultId");

        // check if new vault ended/exists
        DataTypes.Vault memory newVault = vaults[newVaultId];
        if(newVault.endTime <= block.timestamp) revert Errors.VaultEnded(newVaultId, newVault.endTime);
        if(newVault.creator == address(0)) revert Errors.NonExistentVault(newVaultId);

        // check if vault exists + cache vault & user's vault assets
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory oldVault) = _cache(oldVaultId, msg.sender);

        // Update all distributions, their respective vault accounts, and user accounts for the old vault
        _updateUserAccounts(msg.sender, oldVaultId, oldVault, userVaultAssets);
        
        //note: user may or may not have assets already staked in the new vault
        // Update all distributions, their respective vault accounts, and user accounts for the new vault
        _updateUserAccounts(msg.sender, newVaultId, newVault, userVaultAssets);

        // increment new vault: base assets
        newVault.stakedNfts += userVaultAssets.tokenIds.length;
        newVault.stakedTokens += userVaultAssets.stakedTokens;
        newVault.stakedRealmPoints += userVaultAssets.stakedRealmPoints;
        // update boost
        newVault.totalBoostFactor += userVaultAssets.tokenIds.length * NFT_MULTIPLIER;
        newVault.boostedStakedTokens = (newVault.stakedTokens * newVault.totalBoostFactor) / PRECISION_BASE; 
        newVault.boostedRealmPoints = (newVault.stakedRealmPoints * newVault.totalBoostFactor) / PRECISION_BASE; 


        // decrement oldVault
        oldVault.stakedNfts -= userVaultAssets.tokenIds.length;
        oldVault.stakedTokens -= userVaultAssets.stakedTokens;
        oldVault.stakedRealmPoints -= userVaultAssets.stakedRealmPoints;
        // update boost
        oldVault.totalBoostFactor -= userVaultAssets.tokenIds.length * NFT_MULTIPLIER;
        oldVault.boostedStakedTokens = (oldVault.stakedTokens * oldVault.totalBoostFactor) / PRECISION_BASE; 
        oldVault.boostedRealmPoints = (oldVault.stakedRealmPoints * oldVault.totalBoostFactor) / PRECISION_BASE; 

        // NFT management
            // record unstake with registry
            //NFT_REGISTRY.recordUnstake(msg.sender, userVaultAssets.tokenIds, oldVaultId);
            emit UnstakedMocaNft(msg.sender, oldVaultId, userVaultAssets.tokenIds);       

            // record stake with registry
            //NFT_REGISTRY.recordStake(msg.sender, userVaultAssets.tokenIds, newVaultId);
            emit StakedMocaNft(msg.sender, newVaultId, userVaultAssets.tokenIds);

        // emit something
    }

    // onboard RP
    function stakeRP(bytes32 vaultId, uint256 amount, uint256 expiry, bytes calldata signature) external whenStarted whenNotPaused {
        if(amount < 100 ether) revert Errors.MinimumRpRequired();
        if(expiry < block.timestamp) revert Errors.SignatureExpired();
     
        address onBehalfOf = msg.sender;

        // check if vault exists + cache vault & user's vault assets
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);
        // check if vault has ended
        if(vault.endTime <= block.timestamp) revert Errors.VaultEnded(vaultId, vault.endTime);


        // verify signature
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(keccak256("StakeRp(address user,uint256 vaultId,uint256 amount,uint256 expiry)"), onBehalfOf, vaultId, amount, expiry)));
        
        address signer = ECDSA.recover(digest, signature);
        if(signer != STORED_SIGNER) revert Errors.InvalidSignature(); 


        // Update all distributions, their respective vault accounts, and user accounts for specified vault
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        // calc. boostedStakedRealmPoints
        uint256 incomingBoostedStakedRealmPoints = (amount * vault.totalBoostFactor) / PRECISION_BASE;

        // increment: vault
        vault.stakedRealmPoints += amount;
        vault.boostedRealmPoints += incomingBoostedStakedRealmPoints;

        //increment: userVaultAssets
        userVaultAssets.stakedRealmPoints += amount;
        userVaultAssets.boostedRealmPoints += incomingBoostedStakedRealmPoints;

        //increment: user global
        //......
        
        
        // update storage: mappings 
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userVaultAssets;

        // update storage: variables
        totalStakedRealmPoints += amount;
        totalBoostedRealmPoints += incomingBoostedStakedRealmPoints;

        // emit StakedMoca(onBehalfOf, vaultId, amount);
    }

    //function stakeRP(vaultId, amount, expiry, signature) external whenStarted whenNotPaused {}


    /**
        add checks:
        - check if vault has ended
        - check if vault should stop earning rewards - if so do not update; or update as per last

        document
        - how rewards are calculated: distribution, vault, user

     */

//-------------------------------internal-------------------------------------------


    // update all active distributions: book prior rewards, based on prior alloc points 
    function _updateDistributionIndexes() internal {
        if(activeDistributions.length == 0) revert Errors.NoActiveDistributions(); // at least staking power should have been setup on deployment

        uint256 numOfDistributions = activeDistributions.length;

        for(uint256 i; i < numOfDistributions; ++i) {

            // update storage
            distributions[activeDistributions[i]] = _updateDistributionIndex(distributions[activeDistributions[i]]);
        }
    }
/*
    // update all vault accounts per active distribution, for specified vault
    function _updateVaultAllAccounts(bytes32 vaultId) internal {

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
    function _updateDistributionIndex(DataTypes.Distribution memory distribution) internal returns (DataTypes.Distribution memory) {
        
        // already updated: return
        if(distribution.lastUpdateTimeStamp == block.timestamp) return distribution;
        
        uint256 nextDistributionIndex;
        uint256 currentTimestamp;
        uint256 emittedRewards;

        // select appropriate totalBoostedBalance based on distribution type
        // staked RP is the base of Staking power rewards | staked Moca is the base of token rewards
        uint256 totalBoostedBalance = distribution.distributionId == 0 ? totalBoostedRealmPoints : totalBoostedStakedTokens;
        (nextDistributionIndex, currentTimestamp, emittedRewards) = _calculateDistributionIndex(distribution.index, distribution.emissionPerSecond, distribution.lastUpdateTimeStamp, totalBoostedBalance, distribution.TOKEN_PRECISION);
        
        if(nextDistributionIndex != distribution.index) {
            
            // prev timestamp, oldIndex, newIndex: emit prev timestamp since you know the currentTimestamp as per txn time
            // emit VaultIndexUpdated(pool_.lastUpdateTimeStamp, pool_.index, nextPoolIndex); note: update event

            // index and emitted rewards are in reward token precision
            distribution.index = nextDistributionIndex;
            distribution.totalEmitted += emittedRewards; 
            distribution.lastUpdateTimeStamp = currentTimestamp;
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
        
        // emissionPerSecond expressed w/ full token precision 
        uint256 emittedRewards = emissionPerSecond * timeDelta;

        //note: totalBalance is expressed 1e18. 
        //      emittedRewards is variable as per distribution.TOKEN_PRECISION
        //      normalize totalBalance to reward token's native precision
        //      why: paying out rewards token, standardize to that
        uint256 totalBalanceRebased = (totalBalance * distributionPrecision) / 1E18;  // what if its already 1e18? do we want to bother with an if check?

        //note: indexes are denominated in the distribution's precision
        uint256 nextDistributionIndex = (emittedRewards * distributionPrecision / totalBalanceRebased) + currentDistributionIndex; 

    
        return (nextDistributionIndex, currentTimestamp, emittedRewards);
    }


    // update specified vault account
    // returns updated vault account and updated distribution structs 
    function _updateVaultAccount(
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount, 
        DataTypes.Distribution memory distribution_) internal returns (DataTypes.VaultAccount memory, DataTypes.Distribution memory) {

        // get latest distributionIndex
        DataTypes.Distribution memory distribution = _updateDistributionIndex(distribution_);
        
        // vault already been updated by a prior txn; skip updating
        if(distribution.index == vaultAccount.index) return (vaultAccount, distribution_);

        // If vault has ended, vaultIndex should not be updated, beyond the final update.
        if(block.timestamp >= vault.endTime) return (vaultAccount, distribution_);

        // update vault rewards + fees
        uint256 totalAccRewards; 
        uint256 accCreatorFee; 
        uint256 accTotalNftFee;
        uint256 accRealmPointsFee;

        // STAKING POWER: staked realm points | TOKENS: staked moca tokens
        uint256 boostedBalance = distribution.distributionId == 0 ? vault.boostedRealmPoints : vault.boostedStakedTokens;
        uint256 totalBalanceRebased = (boostedBalance * distribution.TOKEN_PRECISION) / 1E18;  
        // note: rewards calc. in reward token precision
        totalAccRewards = _calculateRewards(totalBalanceRebased, distribution.index, vaultAccount.index);

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
        
        // book rewards: total, Creator, NFT, RealmPoints | expressed in distri token precision
        vaultAccount.totalAccRewards += totalAccRewards;
        vaultAccount.accCreatorRewards += accCreatorFee;
        vaultAccount.accNftStakingRewards += accTotalNftFee;
        vaultAccount.accRealmPointsRewards += accRealmPointsFee;

        // reference for moca stakers to calc. rewards net of fees
        uint256 totalStakedRebased = (vault.stakedTokens * distribution.TOKEN_PRECISION) / 1E18;
        vaultAccount.rewardsAccPerUnitStaked += (totalAccRewards - accCreatorFee - accTotalNftFee - accRealmPointsFee) / totalStakedRebased;  

        // update vaultIndex
        vaultAccount.index = distribution.index;

        // emit VaultIndexUpdated    

        return (vaultAccount, distribution);
    }

    function _updateUserAccount(
        DataTypes.User memory user, DataTypes.UserAccount memory userAccount, 
        DataTypes.Vault memory vault, DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution_) internal returns (DataTypes.UserAccount memory, DataTypes.VaultAccount memory, DataTypes.Distribution memory) {
        
        // get updated vaultAccount and distribution
        (DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _updateVaultAccount(vault, vaultAccount, distribution_);
        
        uint256 newUserIndex = vaultAccount.rewardsAccPerUnitStaked;

        // if this index has not been updated, the subsequent ones would not have. check once here, no need repeat
        if(userAccount.index != newUserIndex) { 

            if(user.stakedTokens > 0) {
                // users whom staked tokens are eligible for rewards less of fees
                uint256 balanceRebased = (user.stakedTokens * distribution.TOKEN_PRECISION) / 1E18;
                uint256 accruedRewards = _calculateRewards(balanceRebased, newUserIndex, userAccount.index);
                userAccount.accStakingRewards += accruedRewards;

                // emit RewardsAccrued(user, accruedRewards, distributionPrecision);
            }


            uint256 userStakedNfts = user.tokenIds.length;
            if(userStakedNfts > 0) {

                // total accrued rewards from staking NFTs
                uint256 accNftStakingRewards = (vaultAccount.nftIndex - userAccount.nftIndex) * userStakedNfts;
                userAccount.accNftStakingRewards += accNftStakingRewards;

                //emit NftRewardsAccrued(user, accNftStakingRewards);
            }


            if(user.stakedRealmPoints > 0){
                
                // users whom staked RP are eligible for a portion of RP fees
                uint256 totalStakedRpRebased = (vault.stakedRealmPoints * distribution.TOKEN_PRECISION) / 1E18;

                uint256 accRealmPointsRewards = (vaultAccount.rpIndex - userAccount.rpIndex) * totalStakedRpRebased;
                userAccount.accRealmPointsRewards += accRealmPointsRewards;

                //emit something
            }

        }


        // update user indexes
        userAccount.index = vaultAccount.rewardsAccPerUnitStaked;   // less of fees
        userAccount.nftIndex = vaultAccount.nftIndex;
        userAccount.rpIndex = vaultAccount.rpIndex;

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
            DataTypes.Distribution memory distribution_ = distributions[distributionId];
            DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[vaultId][distributionId];
            DataTypes.UserAccount memory userAccount_ = userAccounts[user][vaultId][distributionId];

            
            (DataTypes.UserAccount memory userAccount, DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _updateUserAccount(userVaultAssets, userAccount_, vault, vaultAccount_, distribution_);

            //update storage: accounts and distributions
            distributions[distributionId] = distribution;     
            vaultAccounts[vaultId][distributionId] = vaultAccount;  
            userAccounts[user][vaultId][distributionId] = userAccount;
        }
 
    }

    // for calc. rewards from index deltas. assumes tt indexes are expressed in the distribution's precision. therefore balance must be rebased to the same precision
    function _calculateRewards(uint256 balanceRebased, uint256 currentIndex, uint256 priorIndex) internal pure returns (uint256) {
        return (balanceRebased * (currentIndex - priorIndex)) / 1E18;
    }


    ///@dev cache vault and user structs from storage to memory. checks that vault exists, else reverts.
    function _cache(bytes32 vaultId, address onBehalfOf) internal view returns(DataTypes.User memory, DataTypes.Vault memory) {
        
        // ensure vault exists
        DataTypes.Vault memory vault = vaults[vaultId];
        if(vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);

        // get global and vault level user data
        //DataTypes.User memory userGlobal = users[onBehalfOf];
        DataTypes.User memory userVaultAssets = users[onBehalfOf][vaultId];

        return (/*userGlobal*/ userVaultAssets, vault);
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
    
    //note: endVaults follows the same pattern. maybe make separate internal fns for these 2.
    function updateNftMultiplier(uint256 newMultiplier) external onlyOwner {
        require(newMultiplier > 0);


        NFT_MULTIPLIER = newMultiplier;

        // emit
    }

    function updateAllVaultsAndAccounts(bytes32[] calldata vaultIds) external {
        uint256 numOfVaults = vaultIds.length;
        require(numOfVaults > 0, "Invalid array");

        
        for(uint256 i; i < numOfVaults; ++i) {

           // _updateVaultAllAccounts(bytes32 vaultId);
        }

        // emit
    }   
    
    //note: for each vault, update its boosted balances, then update its respective users
    // ensure NFT_MULTIPLIER has been changed before calling this fn
    function updateBoostedBalances(bytes32[] calldata vaultIds, address[][] calldata userAddresses) external onlyOwner {
        uint256 numOfVaults = vaultIds.length;
        require(numOfVaults > 0, "Invalid array");

        if(numOfVaults != userAddresses.length) revert();

        // for each vault
        for(uint256 i; i < numOfVaults; ++i) {
            
            bytes32 vaultId = vaultIds[i];

            // get vault + ensure it exists
            DataTypes.Vault memory vault = vaults[vaultId];
            if(vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);

            // decrement global totals before updating vault
            totalBoostedRealmPoints -= vault.boostedRealmPoints;
            totalBoostedStakedTokens -= vault.boostedStakedTokens;

            // update vault with new multiplier
            vault.totalBoostFactor = vault.stakedNfts * NFT_MULTIPLIER;
            vault.boostedRealmPoints = (vault.stakedRealmPoints * vault.totalBoostFactor) / PRECISION_BASE;    
            vault.boostedStakedTokens = (vault.stakedTokens * vault.totalBoostFactor) / PRECISION_BASE;

            uint256 numOfUsersPerVault = userAddresses[i].length;

            // for each vault for user i
            for(uint256 j; j < numOfUsersPerVault; ++j){
                address userAddress = userAddresses[i][j];
    
                // Fixed: Access the mapping correctly using the user's address and vaultId
                DataTypes.User memory userVaultAssets = users[userAddress][vaultId];

                userVaultAssets.boostedRealmPoints = (userVaultAssets.stakedRealmPoints * vault.totalBoostFactor) / PRECISION_BASE;
                userVaultAssets.boostedStakedTokens = (userVaultAssets.stakedTokens * vault.totalBoostFactor) / PRECISION_BASE;

                // Don't forget to write back to storage
                users[userAddress][vaultId] = userVaultAssets;
            }

            // Write back vault changes to storage
            vaults[vaultId] = vault;

            // increment global totals with new values
            totalBoostedRealmPoints += vault.boostedRealmPoints;
            totalBoostedStakedTokens += vault.boostedStakedTokens;
        }

        // emit
    }

/*
        uint256 numOfVaults = numberOfVaults;
        uint256 numOfDistributions = activeDistributions.length; // always >= 1; staking power


        // close the books: for each distribution, update all vaultAccounts
        // no need to update userAccounts and their indexes, since users within a vault operate w/ the same boost
        for(uint256 i; i < numOfVaults; ++i) {

            DataTypes.Vault memory vault = vaults[i];
            
            // Update vault account for each active distribution
            for(uint256 j; j < numOfDistributions; ++j) {
                uint256 distributionId = activeDistributions[j];

                DataTypes.Distribution memory distribution_ = distributions[distributionId];
                DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[i][distributionId];

                // returns memory structs
                (DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _updateVaultAccount(vault, vaultAccount_, distribution_);

                // Update storage
                vaultAccounts[i][distributionId] = vaultAccount;
                if(distribution.lastUpdateTimeStamp < distribution_.lastUpdateTimeStamp){
                    distributions[distributionId] = distribution;
                }

            }
        }
*/


    /**
     * @notice Updates the number of NFTs required to create a vault
     * @dev Zero values are accepted, allowing vault creation without NFT requirements
     * @param newAmount The new number of NFTs required for vault creation
     */
    function updateCreationNfts(uint256 newAmount) external onlyOwner {
        uint256 oldAmount = CREATION_NFTS_REQUIRED;
        CREATION_NFTS_REQUIRED = newAmount; 

        emit CreationNftRequirementUpdated(oldAmount, newAmount);
    }

    /**
     * @notice Updates the cooldown duration for vaults
     * @dev Zero values are accepted. New duration can be less or more than current value
     * @param newDuration The new cooldown duration to set
     */
    function updateVaultCooldown(uint256 newDuration) external onlyOwner {
        // require contract not paused/ended

        emit VaultCooldownDurationUpdated(VAULT_COOLDOWN_DURATION, newDuration);
        
        VAULT_COOLDOWN_DURATION = newDuration;
    }


    /**
     * @notice Sets up a new token distribution schedule
     * @dev Can only be called by contract owner. Distribution must not already exist.
     * @param distributionId Unique identifier for this distribution
     * @param startTime Timestamp when distribution begins, must be in the future
     * @param endTime Timestamp when distribution ends
     * @param emissionPerSecond Rate of token emissions per second
     * @param tokenPrecision Decimal precision for the distributed token
     * @custom:throws Errors.DistributionAlreadySetup if distribution with ID already exists
     * @custom:emits DistributionUpdated when distribution is created
     */
    function setupDistribution(uint256 distributionId, uint256 startTime, uint256 endTime, uint256 emissionPerSecond, uint256 tokenPrecision) external onlyOwner {
        require(emissionPerSecond > 0, "emissionPerSecond = 0");
        require(tokenPrecision > 0, "tokenPrecision = 0");

        require(startTime > block.timestamp, "Invalid startTime");
        require(endTime > startTime, "Invalid endtime");

        // only staking power can have indefinite endTime
        if(distributionId > 0 && endTime == 0) revert Errors.InvalidEndTime();

        DataTypes.Distribution memory distribution = distributions[distributionId]; 
        
        // check if fresh id
        if(distribution.startTime > 0) revert Errors.DistributionAlreadySetup();
            
            distribution.distributionId = distributionId;
            distribution.TOKEN_PRECISION = tokenPrecision;
            
            distribution.endTime = endTime;
            distribution.startTime = startTime;
            distribution.emissionPerSecond = emissionPerSecond;
            
            distribution.lastUpdateTimeStamp = startTime;

        // update storage
        distributions[distributionId] = distribution;

        // update distribution tracking
        activeDistributions.push(distributionId);
        ++ totalDistributions;

        emit DistributionCreated(distributionId, startTime, endTime, emissionPerSecond, tokenPrecision);
    }

    /** 
     * @notice Updates the parameters of an existing distribution
     * @dev Can modify:
     *      - startTime (only if distribution hasn't started)
     *      - endTime (can extend or shorten, must be >= block.timestamp)
     *      - emission rate (can be modified at any time)
     * @dev At least one parameter must be modified (non-zero)
     * @param distributionId ID of the distribution to update
     * @param newStartTime New start time for the distribution. Must be > block.timestamp if modified
     * @param newEndTime New end time for the distribution. Must be >= block.timestamp if modified
     * @param newEmissionPerSecond New emission rate per second. Must be > 0 if modified
     * @custom:throws Errors.InvalidDistributionParameters if all parameters are 0
     * @custom:throws Errors.DistributionEnded if distribution has already ended
     * @custom:throws Errors.DistributionStarted if trying to modify start time after distribution started
     * @custom:throws Errors.InvalidStartTime if new start time is not in the future
     * @custom:throws Errors.InvalidEndTime if new end time is not in the future
     * @custom:throws "Pool is frozen" if pool is in frozen state
     * @custom:emits DistributionUpdated when distribution parameters are modified
     */
    function updateDistribution(uint256 distributionId, uint256 newStartTime, uint256 newEndTime, uint256 newEmissionPerSecond) external onlyOwner {
        // check if pool is frozen/ended
        require(!isFrozen, "Pool is frozen");

        if(newStartTime == 0 && newEndTime == 0 && newEmissionPerSecond == 0) revert Errors.InvalidDistributionParameters(); 

        // get distribution
        DataTypes.Distribution memory distribution = distributions[distributionId];

        // is distribution ended? | okay if not started or started 
        if(block.timestamp >= distribution.endTime) revert Errors.DistributionEnded();
        
        // close the books: update distribution
        _updateDistributionIndex(distribution);

        // ---------------- modifications -------------------------

        // startTime modification
        if(newStartTime > 0) {
            
            // cannot update startTime once distribution has started
            if(distribution.startTime >= block.timestamp) revert Errors.DistributionStarted();
            
            // newStartTime must be a future time
            if(newStartTime > block.timestamp) revert Errors.InvalidStartTime();

            distribution.startTime = newStartTime;
        }
        
        // endTime modification
        if(newEndTime > 0) {
            
            // cannot be in the past
            if(newEndTime < block.timestamp) revert Errors.InvalidEndTime();

            // can modify to shorten or extend a distribution
            // set endTime to block.timestamp to end it immediately
            distribution.endTime = newEndTime;
        }

        // emissionPerSecond modification 
        if(newEmissionPerSecond > 0) distribution.emissionPerSecond = newEmissionPerSecond;

        // ---------------- ------------- -------------------------

        // update storage
        distributions[distributionId] = distribution;

        emit DistributionUpdated(distributionId, distribution.startTime, distribution.endTime, distribution.emissionPerSecond);
    }


    /**
     * @notice Updates the rewards vault address
     * @dev Only callable by owner
     * @param newRewardsVault The address of the new rewards vault contract
     * @custom:throws If newRewardsVault is zero address
     * @custom:emits RewardsVaultSet event with old and new vault addresses
     */
    function setRewardsVault(address newRewardsVault) external onlyOwner {
        require(newRewardsVault != address(0), "Invalid address");

        emit RewardsVaultSet(address(REWARDS_VAULT), newRewardsVault);
        REWARDS_VAULT = IRewardsVault(newRewardsVault);    
    }



//------------------------------- risk ----------------------------------------------------


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
    /*  
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
        //vaults[vaultId] = vault;
        //users[onBehalfOf][vaultId] = userInfo;

        // return principal stake
        //if(stakedTokens > 0) STAKED_TOKEN.safeTransfer(onBehalfOf, stakedTokens); 
    
    }


    /**  NOTE: Consider dropping to avoid admin abuse
     * @notice Recover random tokens accidentally sent to the vault
     * @param tokenAddress Address of token contract
     * @param receiver Recepient of tokens
     * @param amount Amount to retrieve
     */
    function recoverERC20(address tokenAddress, address receiver, uint256 amount) external onlyOwner {
        require(tokenAddress != address(STAKED_TOKEN), "StakedToken: Not allowed");

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