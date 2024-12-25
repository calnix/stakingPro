// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import './Events.sol';
import './Errors.sol';
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
    address public immutable STORED_SIGNER;                 // can this be immutable? 
    
    IRewardsVault public REWARDS_VAULT;

    // period
    uint256 public immutable startTime; // can start arbitrarily after deployment
    uint256 public endTime;             //note: if we need to end 

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
    uint256 public MINIMUM_REALMPOINTS_REQUIRED;
    
    //--------------------------------

    /** track token distributions

        each distribution has an id
        two different distributionsIds could lead to the same token - w/ just different distribution schedules
        
        each time a vault is updated we must update all the active tokenIndexes,
        which means we must loop through all the active indexes.
     */
    
    // array stores key values for distributions mapping. active includes not yet started distributions
    uint256[] public activeDistributions;    // we do not expect a large number of concurrently active distributions
    uint256 public totalDistributions;
    uint256 public completedDistributions;  // note: when does this get updated?

    struct StakeRp {
        address user;
        bytes32 vaultId;
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

    // user's assets per vault
    mapping(address user => mapping(bytes32 vaultId => DataTypes.User userVaultAssets)) public users;

    // for independent reward distribution tracking              
    mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.VaultAccount vaultAccount)) public vaultAccounts;

    // rewards accrued per user, per distribution
    mapping(address user => mapping(bytes32 vaultId => mapping(uint256 distributionId => DataTypes.UserAccount userAccount))) public userAccounts;

    // replay attack: 1 is true, 0 is false
    mapping(bytes32 signature => uint256 executed) public executedSignatures;


//-------------------------------constructor------------------------------------------

    constructor(address registry, address stakedToken, address storedSigner, uint256 startTime_, uint256 nftMultiplier, uint256 creationNftsRequired, uint256 vaultCoolDownDuration,
        address owner, string memory name, string memory version) payable EIP712(name, version) Ownable(owner) {

        // sanity check input data: time, period, rewards
        require(owner > address(0), "Zero address");
        require(startTime_ > block.timestamp, "Invalid startTime");

        // interfaces: supporting contracts
        NFT_REGISTRY = INftRegistry(registry);       
        STAKED_TOKEN = IERC20(stakedToken);

        // set stakingPro startTime 
        startTime = startTime_;

        // storage vars
        STORED_SIGNER = storedSigner;
        NFT_MULTIPLIER = nftMultiplier;
        CREATION_NFTS_REQUIRED = creationNftsRequired;
        VAULT_COOLDOWN_DURATION = vaultCoolDownDuration;
        MINIMUM_REALMPOINTS_REQUIRED = 100 ether;
    }


//-------------------------------external---------------------------------------------

    /**
     * @notice Creates a new vault for staking assets
     * @dev NFTs must be committed to create a vault.
     * @param tokenIds Array of NFT token IDs to commit for vault creation
     * @param fees Fee configuration for the vault containing:
     *            - nftFeeFactor: Percentage of rewards allocated to NFT stakers
     *            - creatorFeeFactor: Percentage of rewards allocated to vault creator
     *            - realmPointsFeeFactor: Percentage of rewards allocated to realm points
     * @custom:requirements
     * - Caller must own all NFTs being committed
     * - NFTs must not be already staked in another vault
     * - Number of NFTs must match CREATION_NFTS_REQUIRED
     * - Total fee factors must not exceed 50% (5000/10000)
     * - Contract must not be paused and staking must have started
     * @custom:emits VaultCreated event with creator address and vault ID
     */
    function createVault(uint256[] calldata tokenIds, DataTypes.Fees calldata fees) external whenStarted whenNotPaused {
        address onBehalfOf = msg.sender;

        // must commit unstaked NFTs to create vaults: these do not count towards stakedNFTs
        uint256 incomingNfts = tokenIds.length;
        if(incomingNfts != CREATION_NFTS_REQUIRED) revert IncorrectCreationNfts();
        
        for (uint256 i; i < CREATION_NFTS_REQUIRED; i++) {

            (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds[i]);   // note: add batch fn to registry to check ownership
            
            if(owner != onBehalfOf) revert IncorrectNftOwner(tokenIds[i]);
            if(nftVaultId != bytes32(0)) revert NftAlreadyStaked(tokenIds[i]);
        }

        //note: MOCA stakers must receive at least 50% of rewards
        uint256 totalFeeFactor = fees.nftFeeFactor + fees.creatorFeeFactor + fees.realmPointsFeeFactor;
        if(totalFeeFactor > 5000) revert TotalFeeFactorExceeded();

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

        emit VaultCreated(vaultId, onBehalfOf, fees.nftFeeFactor, fees.creatorFeeFactor, fees.realmPointsFeeFactor);

        // record NFT commitment on registry contract
        NFT_REGISTRY.recordStake(onBehalfOf, tokenIds, vaultId);
    }  

    /**
     * @notice Stakes tokens into a vault
     * @dev No staking limits on staking assets
     * @param vaultId The ID of the vault to stake into
     * @param amount The amount of tokens to stake
     * @custom:throws InvalidAmount if amount is 0
     * @custom:throws InvalidVaultId if vaultId is 0
     * @custom:emits StakedMoca when tokens are staked successfully
     */
    function stakeTokens(bytes32 vaultId, uint256 amount) external whenStarted whenNotPaused {
        if(amount == 0) revert InvalidAmount();
        if(vaultId == 0) revert InvalidVaultId();
 
        address onBehalfOf = msg.sender;

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);
        
        // vault cooldown activated: cannot stake
        if(vault.endTime > 0) revert VaultAlreadyEnded(vaultId);

        // Update vault and user accounting across all active reward distributions
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        // calc. boostedStakedTokens
        uint256 incomingBoostedStakedTokens = (amount * vault.totalBoostFactor) / PRECISION_BASE;
        
        // increment: vault
        vault.stakedTokens += amount;
        vault.boostedStakedTokens += incomingBoostedStakedTokens;

        //increment: userVaultAssets
        userVaultAssets.stakedTokens += amount;

        // update storage: mappings 
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userVaultAssets;
        // update storage: variables
        totalStakedTokens += amount;
        totalBoostedStakedTokens += incomingBoostedStakedTokens;
        
        emit StakedTokens(onBehalfOf, vaultId, amount);

        // grab MOCA
        STAKED_TOKEN.safeTransferFrom(onBehalfOf, address(this), amount);
    }

    /**
     * @notice Stakes NFTs into a vault
     * @dev No staking limits on NFT assets. NFTs increase the boost factor for staked tokens and realm points.
     * @param vaultId The ID of the vault to stake NFTs into
     * @param onBehalfOf The address to stake NFTs on behalf of
     * @param tokenIds Array of NFT token IDs to stake
     * @custom:throws InvalidVaultId if vaultId is 0
     * @custom:throws InvalidAmount if tokenIds array is empty
     * @custom:emits StakedNfts when NFTs are staked successfully
     * @custom:emits VaultMultiplierUpdated when vault's boosted balances are updated
     */
    function stakeNfts(bytes32 vaultId, address onBehalfOf, uint256[] calldata tokenIds) external whenStarted whenNotPaused {
        uint256 incomingNfts = tokenIds.length;

        if(vaultId == 0) revert InvalidVaultId();
        if(incomingNfts == 0) revert InvalidAmount();
        
        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);

        // vault cooldown activated: cannot stake
        if(vault.endTime > 0) revert VaultAlreadyEnded(vaultId);

        // Update vault and user accounting across all active reward distributions
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

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

        // update storage: mappings 
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userVaultAssets;

        // update storage: global variables 
        totalStakedNfts += incomingNfts;
        totalBoostedRealmPoints += (vault.boostedRealmPoints - oldBoostedRealmPoints);
        totalBoostedStakedTokens += (vault.boostedStakedTokens - oldBoostedStakedTokens);

        emit StakedNfts(onBehalfOf, vaultId, tokenIds);
        emit VaultMultiplierUpdated(vaultId, oldBoostedStakedTokens, vault.boostedStakedTokens);

        // record stake with registry
        NFT_REGISTRY.recordStake(onBehalfOf, tokenIds, vaultId);
    }

    /**
     * @notice Stakes realm points into a vault
     * @dev Requires a valid signature from the stored signer to authorize the staking
     * @param vaultId The ID of the vault to stake realm points into
     * @param amount The amount of realm points to stake
     * @param expiry The expiry timestamp for the signature
     * @param signature The EIP712 signature authorizing the staking
     * @custom:throws SignatureExpired if signature has expired
     * @custom:throws MinimumRpRequired if amount is below MINIMUM_REALMPOINTS_REQUIRED
     * @custom:throws InvalidSignature if signature is not from STORED_SIGNER
     * @custom:emits StakedRealmPoints when realm points are successfully staked
     */
    function stakeRP(bytes32 vaultId, uint256 amount, uint256 expiry, bytes calldata signature) external whenStarted whenNotPaused {
        if(expiry < block.timestamp) revert SignatureExpired();
        if(amount < MINIMUM_REALMPOINTS_REQUIRED) revert MinimumRpRequired();
     
        address onBehalfOf = msg.sender;

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);

        // vault cooldown activated: cannot stake
        if(vault.endTime > 0) revert VaultAlreadyEnded(vaultId);

        // verify signature
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("StakeRp(address user,bytes32 vaultId,uint256 amount,uint256 expiry)"), 
            onBehalfOf, vaultId, amount, expiry)));
        
        address signer = ECDSA.recover(digest, signature);
        if(signer != STORED_SIGNER) revert InvalidSignature(); 

        // Update vault and user accounting across all active reward distributions
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        // calc. boostedStakedRealmPoints
        uint256 incomingBoostedStakedRealmPoints = (amount * vault.totalBoostFactor) / PRECISION_BASE;

        // increment: vault
        vault.stakedRealmPoints += amount;
        vault.boostedRealmPoints += incomingBoostedStakedRealmPoints;

        //increment: userVaultAssets
        userVaultAssets.stakedRealmPoints += amount;
        
        // update storage: mappings 
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userVaultAssets;

        // update storage: variables
        totalStakedRealmPoints += amount;
        totalBoostedRealmPoints += incomingBoostedStakedRealmPoints;

        // Mark signature as used
        executedSignatures[digest] = 1;

        emit StakedRealmPoints(onBehalfOf, vaultId, amount, incomingBoostedStakedRealmPoints);
    }

    /**
     * @notice Unstakes all tokens and NFTs from a vault
     * @dev Updates accounting, transfers tokens, and records NFT unstaking
     * @param vaultId The ID of the vault to unstake from
     * @custom:emits UnstakedTokens, UnstakedNfts
     */
    function unstakeAll(bytes32 vaultId) external whenStarted whenNotPaused {
        if(vaultId == 0) revert InvalidVaultId();

        address onBehalfOf = msg.sender;
        
        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);

        // Update vault and user accounting across all active reward distributions
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        // get user staked assets: old values for events
        uint256 numOfNfts = userVaultAssets.tokenIds.length;
        uint256 stakedTokens = userVaultAssets.stakedTokens;        

        // check if user has non-zero holdings
        if(stakedTokens + numOfNfts == 0) revert UserHasNothingStaked(vaultId, onBehalfOf);
        
        // update tokens
        if(stakedTokens > 0){

            // calc. boosted values
            uint256 userBoostedStakedTokens = (stakedTokens * vault.totalBoostFactor) / PRECISION_BASE;

            // update vault
            vault.stakedTokens -= stakedTokens;
            vault.boostedStakedTokens -= userBoostedStakedTokens;
            
            // update user
            delete userVaultAssets.stakedTokens;

            // update global
            totalStakedTokens -= stakedTokens;
            totalBoostedStakedTokens -= userBoostedStakedTokens;

            emit UnstakedTokens(onBehalfOf, vaultId, stakedTokens);       

            // return MOCA
            STAKED_TOKEN.safeTransfer(onBehalfOf, stakedTokens);
        }

        // update nfts
        if(numOfNfts > 0){

            // record unstake with registry
            NFT_REGISTRY.recordUnstake(onBehalfOf, userVaultAssets.tokenIds, vaultId);
            emit UnstakedNfts(onBehalfOf, vaultId, userVaultAssets.tokenIds);       

            // update user
            delete userVaultAssets.tokenIds;

            // update vault
            vault.stakedNfts -= numOfNfts;            
            vault.totalBoostFactor = vault.stakedNfts * NFT_MULTIPLIER;

            // recalc vault's boosted balances, based on remaining staked assets
            if (vault.stakedTokens > 0) vault.boostedStakedTokens = (vault.stakedTokens * vault.totalBoostFactor) / PRECISION_BASE;            
            if (vault.stakedRealmPoints > 0) vault.boostedRealmPoints = (vault.stakedRealmPoints * vault.totalBoostFactor) / PRECISION_BASE;

            // update global
            totalStakedNfts -= numOfNfts;
        }

        // update storage: mappings 
        vaults[vaultId] = vault;
        users[onBehalfOf][vaultId] = userVaultAssets;
    }

    /**
     * @notice Claims all pending rewards for a user from a specific vault and distribution
     * @param vaultId The ID of the vault to claim rewards from
     * @param distributionId The ID of the reward distribution to claim from
     * @dev Updates vault and user accounting across all active distributions before claiming
     * @dev Calculates and claims 4 types of rewards:
     *      1. MOCA staking rewards
     *      2. Realm Points staking rewards 
     *      3. NFT staking rewards
     *      4. Creator rewards (if caller is vault creator)
     * @dev Not applicable to distributionId:0 which is the staking power distribution
     * @custom:throws InvalidVaultId if vaultId is 0
     * @custom:throws StakingPowerDistribution if distributionId is 0
     * @custom:emits RewardsClaimed when rewards are successfully claimed
     */
    function claimRewards(bytes32 vaultId, uint256 distributionId) external whenStarted whenNotPaused {
        if(vaultId == 0) revert InvalidVaultId();
        if(distributionId == 0) revert StakingPowerDistribution();

        address onBehalfOf = msg.sender;

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);

        // Update vault and user accounting across all active reward distributions
        // _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);

        // get corresponding user+vault account for this active distribution 
        DataTypes.Distribution memory distribution_ = distributions[distributionId];
        DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[vaultId][distributionId];
        DataTypes.UserAccount memory userAccount_ = userAccounts[onBehalfOf][vaultId][distributionId];

        // alternate; update just the specified distribution
        (DataTypes.UserAccount memory userAccount, DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _updateUserAccount(userVaultAssets, userAccount_, vault, vaultAccount_, distribution_);

        //------- calc. and update vault and user accounts --------
        uint256 totalUnclaimedRewards;
        
        // update balances: staking MOCA rewards
        if (userAccount.accStakingRewards > userAccount.claimedStakingRewards) {

            uint256 unclaimedRewards = userAccount.accStakingRewards - userAccount.claimedStakingRewards;
            userAccount.claimedStakingRewards += unclaimedRewards;
            vaultAccount.totalClaimedRewards += unclaimedRewards;

            totalUnclaimedRewards += unclaimedRewards;
        }

        // update balances: staking RP rewards 
        if (userAccount.accRealmPointsRewards > userAccount.claimedRealmPointsRewards) {

            uint256 unclaimedRpRewards = userAccount.accRealmPointsRewards - userAccount.claimedRealmPointsRewards;
            userAccount.claimedRealmPointsRewards += unclaimedRpRewards;
            vaultAccount.totalClaimedRewards += unclaimedRpRewards;

            totalUnclaimedRewards += unclaimedRpRewards;
        }

        // update balances: staking NFT rewards
        if (userAccount.accNftStakingRewards > userAccount.claimedNftRewards) {

            uint256 unclaimedNftRewards = userAccount.accNftStakingRewards - userAccount.claimedNftRewards;
            userAccount.claimedNftRewards += unclaimedNftRewards;
            vaultAccount.totalClaimedRewards += unclaimedNftRewards;

            totalUnclaimedRewards += unclaimedNftRewards;
        }

        // if creator
        if (vault.creator == onBehalfOf) {

            uint256 unclaimedCreatorRewards = vaultAccount.accCreatorRewards - userAccount.claimedCreatorRewards;
            userAccount.claimedCreatorRewards += unclaimedCreatorRewards;
            vaultAccount.totalClaimedRewards += unclaimedCreatorRewards;
            
            totalUnclaimedRewards += unclaimedCreatorRewards;
        }

        // ---------------------------------------------------------------

        // update storage: accounts and distributions
        distributions[distributionId] = distribution;     
        vaultAccounts[vaultId][distributionId] = vaultAccount;  
        userAccounts[onBehalfOf][vaultId][distributionId] = userAccount;

        emit RewardsClaimed(vaultId, onBehalfOf, totalUnclaimedRewards);

        // transfer rewards to user, from rewardsVault
        REWARDS_VAULT.payRewards(distributionId, onBehalfOf, totalUnclaimedRewards);
    }


    /**
     * @notice Updates the fee structure for a vault
     * @dev Only the vault creator can update fees
     * @dev Creator can only decrease their creator fee factor
     * @dev Total of all fees cannot exceed 50%
     * @param vaultId The ID of the vault to update fees for
     * @param fees The new fee structure to apply
     * @custom:throws InvalidVaultId if vaultId is 0
     * @custom:throws UserIsNotVaultCreator if caller is not the vault creator
     * @custom:throws CreatorFeeCanOnlyBeDecreased if new creator fee is higher than current
     * @custom:throws TotalFeeFactorExceeded if total of all fees exceeds 50%
     * @custom:emits CreatorFeeFactorUpdated when creator fee is updated
     * @custom:emits NftFeeFactorUpdated when NFT fee is updated
     * @custom:emits RealmPointsFeeFactorUpdated when realm points fee is updated
     */
    function updateVaultFees(bytes32 vaultId, DataTypes.Fees calldata fees) external whenStarted whenNotPaused {
        if(vaultId == 0) revert InvalidVaultId();
        
        address onBehalfOf = msg.sender;

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, onBehalfOf);

        // vault cooldown activated: cannot update fees
        if(vault.endTime > 0) revert VaultAlreadyEnded(vaultId);

        // sanity check: user must be creator + incoming creatorFeeFactor must be lower than current
        if(vault.creator != onBehalfOf) revert UserIsNotVaultCreator(vaultId, onBehalfOf);
        if(fees.creatorFeeFactor > vault.creatorFeeFactor) revert CreatorFeeCanOnlyBeDecreased(vaultId);
        
        // sanity check: new fee compositions cannot exceed 50%
        uint256 totalFeeFactor = fees.nftFeeFactor + fees.creatorFeeFactor + fees.realmPointsFeeFactor;
        if(totalFeeFactor > 5000) revert TotalFeeFactorExceeded();     // 50% = 5000/10_000 = 5000/PRECISION_BASE

        // Update vault and user accounting across all active reward distributions
        _updateUserAccounts(onBehalfOf, vaultId, vault, userVaultAssets);
                
        // cache old fees for events
        uint256 oldCreatorFeeFactor = vault.creatorFeeFactor;
        uint256 oldNftFeeFactor = vault.nftFeeFactor;
        uint256 oldRealmPointsFeeFactor = vault.realmPointsFeeFactor;

        // update fees
        vault.nftFeeFactor = fees.nftFeeFactor;
        vault.creatorFeeFactor = fees.creatorFeeFactor;
        vault.realmPointsFeeFactor = fees.realmPointsFeeFactor;
        
        // update storage 
        vaults[vaultId] = vault;

        // emit events for fee changes
        emit CreatorFeeFactorUpdated(vaultId, oldCreatorFeeFactor, fees.creatorFeeFactor);
        emit NftFeeFactorUpdated(vaultId, oldNftFeeFactor, fees.nftFeeFactor);
        emit RealmPointsFeeFactorUpdated(vaultId, oldRealmPointsFeeFactor, fees.realmPointsFeeFactor);
    }

    /**
     * @notice Activates the cooldown period for a vault
     * @dev If VAULT_COOLDOWN_DURATION is 0, vault is immediately removed from circulation
     * @dev When removed, all vault's staked assets are deducted from global totals
     * @param vaultId The ID of the vault to activate cooldown for
     * @custom:throws InvalidVaultId if vaultId is 0
     * @custom:emits VaultRemoved when vault is immediately removed (zero cooldown)
     * @custom:emits VaultCooldownInitiated when cooldown period begins
     */
    function activateCooldown(bytes32 vaultId) external whenStarted whenNotPaused {
        if(vaultId == 0) revert InvalidVaultId();

        // cache vault and user data, reverts if vault does not exist
        (DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault) = _cache(vaultId, msg.sender);

        // Update vault and user accounting across all active reward distributions
        _updateUserAccounts(msg.sender, vaultId, vault, userVaultAssets);

        // vault cooldown already activated: cannot activate again
        if(vault.endTime > 0) revert VaultAlreadyEnded(vaultId);

        // set endTime       
        vault.endTime = block.timestamp + VAULT_COOLDOWN_DURATION;

        // if zero cooldown, remove vault from circulation immediately 
        if(VAULT_COOLDOWN_DURATION == 0) {
            
            vault.removed = 1;

            // decrement state vars
            totalStakedNfts -= vault.stakedNfts;
            totalStakedTokens -= vault.stakedTokens;
            totalStakedRealmPoints -= vault.stakedRealmPoints;

            totalBoostedRealmPoints -= vault.boostedRealmPoints;
            totalBoostedStakedTokens -= vault.boostedStakedTokens;

            emit VaultRemoved(vaultId);

        } else {
            emit VaultCooldownInitiated(vaultId);
        }

        // update storage
        vaults[vaultId] = vault;
    }

    // note: may want to flip the loop order
    // REVIEW AFTER FINALIZING ALL INTERNAL FUNCTIONS
    function endVaults(bytes32[] calldata vaultIds) external whenStarted whenNotPaused {
        uint256 numOfVaults = vaultIds.length;
        if(numOfVaults == 0) revert InvalidArray();

        uint256 numOfDistributions = activeDistributions.length;

        // Track total assets to remove from global state
        uint256 totalNftsToRemove;
        uint256 totalTokensToRemove; 
        uint256 totalRealmPointsToRemove;
        uint256 totalBoostedTokensToRemove;
        uint256 totalBoostedRealmPointsToRemove;

        uint256 vaultsEnded;

        // For each distribution
        for(uint256 i; i < numOfDistributions; ++i) {
            uint256 distributionId = activeDistributions[i];
            DataTypes.Distribution memory distribution_ = distributions[distributionId];

            // Update distribution first
            DataTypes.Distribution memory distribution = _updateDistributionIndex(distribution_);

            // Then update all vault accounts for this distribution
            for(uint256 j; j < numOfVaults; ++j) {
                
                // get vault and vault account from storage
                bytes32 vaultId = vaultIds[j];
                DataTypes.Vault memory vault = vaults[vaultId];
                DataTypes.VaultAccount memory vaultAccount_ = vaultAccounts[vaultId][distributionId];

                // cooldown NOT activated; cannot end vault: skip
                if(vault.endTime == 0) continue;
                // vault has been removed from circulation: skip
                if(vault.removed == 1) continue;

                // Update storage: vault account 
                (DataTypes.VaultAccount memory vaultAccount,) = _updateVaultAccount(vault, vaultAccount_, distribution);
                vaultAccounts[vaultId][distributionId] = vaultAccount;

                // Track assets to remove (only need to do this once per vault)
                if(i == 0) {
                    totalNftsToRemove += vault.stakedNfts;
                    totalTokensToRemove += vault.stakedTokens;
                    totalRealmPointsToRemove += vault.stakedRealmPoints;
                    totalBoostedTokensToRemove += vault.boostedStakedTokens;
                    totalBoostedRealmPointsToRemove += vault.boostedRealmPoints;

                    // Mark vault as removed
                    vault.removed = 1;
                    ++vaultsEnded;

                    // update storage 
                    vaults[vaultId] = vault;
                }
            }

            // Update distribution storage if changed
            if(distribution.lastUpdateTimeStamp > distribution_.lastUpdateTimeStamp) {
                distributions[distributionId] = distribution;
            }
        }

        // Update global state
        totalStakedNfts -= totalNftsToRemove;
        totalStakedTokens -= totalTokensToRemove;
        totalStakedRealmPoints -= totalRealmPointsToRemove;
        totalBoostedStakedTokens -= totalBoostedTokensToRemove;
        totalBoostedRealmPoints -= totalBoostedRealmPointsToRemove;

        // Emit event for each removed vault
        uint256 vaultsNotEnded = numOfVaults - vaultsEnded;
        emit VaultsRemoved(vaultIds, vaultsNotEnded);
    }

    /**
     * @notice Migrates user's assets from one vault to another
     * @dev Updates accounting for both vaults and user's assets, including NFT boost factors
     * @param oldVaultId ID of the vault to migrate assets from
     * @param newVaultId ID of the vault to migrate assets to
     * @custom:throws InvalidVaultId if either vault ID is 0
     * @custom:emits UnstakedNfts when NFTs are unstaked from old vault
     * @custom:emits StakedNfts when NFTs are staked in new vault
     * @custom:emits VaultMigrated when migration is complete
     */
    function migrateVaults(bytes32 oldVaultId, bytes32 newVaultId) external whenStarted whenNotPaused {
        if(oldVaultId == 0) revert InvalidVaultId();
        if(newVaultId == 0) revert InvalidVaultId();

        // cache vault and user data for both vaults, reverts if vault does not exist
        (DataTypes.User memory oldUserVaultAssets, DataTypes.Vault memory oldVault) = _cache(oldVaultId, msg.sender);
        (DataTypes.User memory newUserVaultAssets, DataTypes.Vault memory newVault) = _cache(newVaultId, msg.sender);

        // vault cooldown activated: cannot migrate
        if(newVault.endTime > 0) revert VaultAlreadyEnded(newVaultId);

        // oldVault: Update vault and user accounting across all active reward distributions
        _updateUserAccounts(msg.sender, oldVaultId, oldVault, oldUserVaultAssets);
        
        // note: user may have assets already staked in the new vault
        // newVault: Update vault and user accounting across all active reward distributions
        _updateUserAccounts(msg.sender, newVaultId, newVault, newUserVaultAssets);

        // increment new vault: base assets (including existing assets)
        newVault.stakedNfts += oldUserVaultAssets.tokenIds.length;
        newVault.stakedTokens += oldUserVaultAssets.stakedTokens;
        newVault.stakedRealmPoints += oldUserVaultAssets.stakedRealmPoints;
        
        // update boost
        newVault.totalBoostFactor += oldUserVaultAssets.tokenIds.length * NFT_MULTIPLIER;
        newVault.boostedStakedTokens = (newVault.stakedTokens * newVault.totalBoostFactor) / PRECISION_BASE; 
        newVault.boostedRealmPoints = (newVault.stakedRealmPoints * newVault.totalBoostFactor) / PRECISION_BASE; 

        // decrement oldVault
        oldVault.stakedNfts -= oldUserVaultAssets.tokenIds.length;
        oldVault.stakedTokens -= oldUserVaultAssets.stakedTokens;
        oldVault.stakedRealmPoints -= oldUserVaultAssets.stakedRealmPoints;
        
        // update boost
        oldVault.totalBoostFactor -= oldUserVaultAssets.tokenIds.length * NFT_MULTIPLIER;
        oldVault.boostedStakedTokens = (oldVault.stakedTokens * oldVault.totalBoostFactor) / PRECISION_BASE; 
        oldVault.boostedRealmPoints = (oldVault.stakedRealmPoints * oldVault.totalBoostFactor) / PRECISION_BASE; 

        // NFT management
        NFT_REGISTRY.recordUnstake(msg.sender, oldUserVaultAssets.tokenIds, oldVaultId);
        emit UnstakedNfts(msg.sender, oldVaultId, oldUserVaultAssets.tokenIds);       

        NFT_REGISTRY.recordStake(msg.sender, oldUserVaultAssets.tokenIds, newVaultId);
        emit StakedNfts(msg.sender, newVaultId, oldUserVaultAssets.tokenIds);

        // Update new user assets: combine NFTs and add migrated assets
        newUserVaultAssets.tokenIds = _concatArrays(newUserVaultAssets.tokenIds, oldUserVaultAssets.tokenIds);
        newUserVaultAssets.stakedTokens += oldUserVaultAssets.stakedTokens;
        newUserVaultAssets.stakedRealmPoints += oldUserVaultAssets.stakedRealmPoints;

        // Update storage for both vaults
        vaults[oldVaultId] = oldVault;
        vaults[newVaultId] = newVault;

        // Clear old user assets and update new user assets
        delete users[msg.sender][oldVaultId];
        users[msg.sender][newVaultId] = newUserVaultAssets;

        // Update global boosted totals
        totalBoostedStakedTokens = totalBoostedStakedTokens - oldVault.boostedStakedTokens + newVault.boostedStakedTokens;
        totalBoostedRealmPoints = totalBoostedRealmPoints - oldVault.boostedRealmPoints + newVault.boostedRealmPoints;

        // Emit migrated assets only (not including existing assets in new vault)
        emit VaultMigrated(
            msg.sender, 
            oldVaultId, 
            newVaultId,
            oldUserVaultAssets.stakedTokens,  // Only migrated tokens
            oldUserVaultAssets.stakedRealmPoints,  // Only migrated realm points
            oldUserVaultAssets.tokenIds.length  // Only migrated NFTs
        );
    }



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
        if(activeDistributions.length == 0) revert NoActiveDistributions(); // at least staking power should have been setup on deployment

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
    
    function _updateDistributionIndex(DataTypes.Distribution memory distribution) internal returns (DataTypes.Distribution memory) {
        // distribution already updated
        if(distribution.lastUpdateTimeStamp == block.timestamp) return distribution;

        // distribution has not started
        if(block.timestamp < distribution.startTime) return distribution;

        // distribution has ended: does not apply to staking power, distributionId == 0
        if (distribution.endTime > 0 && block.timestamp >= distribution.endTime) {

            // If this is the first update after distribution ended, do final update to endTime
            if (distribution.lastUpdateTimeStamp < distribution.endTime) {
                
                // distributions w/ endTimes involve tokens, not realmPoints: use totalBoostedStakedTokens
                (uint256 finalIndex, /*currentTimestamp*/, uint256 finalEmitted) = _calculateDistributionIndex(distribution, totalBoostedStakedTokens);

                distribution.index = finalIndex;
                distribution.totalEmitted += finalEmitted;
                distribution.lastUpdateTimeStamp = distribution.endTime;
                
                emit DistributionIndexUpdated(distribution.distributionId, distribution.lastUpdateTimeStamp, distribution.index, finalIndex);
                
                // Remove from active distributions and mark as completed
                for (uint256 i; i < activeDistributions.length; ++i) {
                    if (activeDistributions[i] == distribution.distributionId) {
                        // Move last element to current position and pop
                        activeDistributions[i] = activeDistributions[activeDistributions.length - 1];
                        activeDistributions.pop();
                        break;
                    }
                }

                ++completedDistributions;
                emit DistributionCompleted(distribution.distributionId, distribution.endTime, distribution.totalEmitted);
            }
            
            return distribution;
        }    

        // ..... Normal update for active distributions: could be for both tokens and realmPoints .....

        uint256 totalBoostedBalance = distribution.distributionId == 0 ? totalBoostedRealmPoints : totalBoostedStakedTokens;
        (uint256 nextIndex, uint256 currentTimestamp, uint256 emittedRewards) = _calculateDistributionIndex(distribution, totalBoostedBalance);
        
        if (nextIndex > distribution.index) {

            distribution.index = nextIndex;
            distribution.totalEmitted += emittedRewards;
            distribution.lastUpdateTimeStamp = currentTimestamp;

            emit DistributionIndexUpdated(distribution.distributionId, distribution.lastUpdateTimeStamp, distribution.index, nextIndex);
        }

        return distribution;
    }

    /**
     * @dev Calculates the latest distribution index and emitted rewards since last update
     * @param distribution The distribution struct containing current state
     * @param totalBalance Total boosted balance (either tokens or realm points) for the distribution
     * @return nextIndex The updated distribution index
     * @return currentTimestamp The timestamp used for the calculation (capped by distribution/contract end time)
     * @return emittedRewards The total rewards emitted since last update
     */
    function _calculateDistributionIndex(DataTypes.Distribution memory distribution, uint256 totalBalance) internal view returns (uint256, uint256, uint256) {
        if (
            totalBalance == 0                                              // nothing has been staked
            || distribution.emissionPerSecond == 0                         // 0 emissions. no rewards setup.
            || distribution.lastUpdateTimeStamp == block.timestamp         // index already updated
            //|| lastUpdateTimestamp > endTime                 // distribution has ended note: contract endTime is referenced. do we need?
        ) {
            return (distribution.index, distribution.lastUpdateTimeStamp, 0);                       
        }

        uint256 currentTimestamp;

        // If distributionEndTime is provided (non-zero), use it as the cap
        if(distribution.endTime > 0) {
            currentTimestamp = block.timestamp > distribution.endTime ? distribution.endTime : block.timestamp;
        } 
        // Otherwise use contract endTime if set
        else if(endTime > 0) {
            currentTimestamp = block.timestamp > endTime ? endTime : block.timestamp;
        }
        // If neither is set, use current block timestamp
        else {
            currentTimestamp = block.timestamp;
        }

        uint256 timeDelta = currentTimestamp - distribution.lastUpdateTimeStamp;
        
        // emissionPerSecond expressed w/ full token precision 
        uint256 emittedRewards;
        unchecked {
            // Overflow is unlikely as timeDelta is bounded by block times
            emittedRewards = distribution.emissionPerSecond * timeDelta;
        }

        //note: totalBalance is expressed 1e18. 
        //      emittedRewards is variable as per distribution.TOKEN_PRECISION
        //      normalize totalBalance to reward token's native precision
        //      why: paying out rewards token, standardize to that
        uint256 totalBalanceRebased = (totalBalance * distribution.TOKEN_PRECISION) / 1E18;  // what if its already 1e18? do we want to bother with an if check?
    
        //note: indexes are denominated in the distribution's precision
        uint256 nextDistributionIndex = ((emittedRewards * distribution.TOKEN_PRECISION) / totalBalanceRebased) + distribution.index; 

    
        return (nextDistributionIndex, currentTimestamp, emittedRewards);
    }


    // update specified vault account
    // returns updated vault account and updated distribution structs 
    function _updateVaultAccount(
        DataTypes.Vault memory vault, 
        DataTypes.VaultAccount memory vaultAccount, 
        DataTypes.Distribution memory distribution_) internal returns (DataTypes.VaultAccount memory, DataTypes.Distribution memory) {

        // get latest distributionIndex, if not already updated
        DataTypes.Distribution memory distribution = _updateDistributionIndex(distribution_);
        
        // vault already been updated by a prior txn; skip updating vaultAccount
        if(distribution.index == vaultAccount.index) return (vaultAccount, distribution);

        // vault has been removed from circulation: final update done by endVaults()
        if(vault.removed == 1) return (vaultAccount, distribution);

        // If vault has ended, vaultIndex should not be updated, beyond the final update.
        /** note:
            - vaults are removed from circulation via endVaults
            - endVaults is responsible for the final update and setting `vault.removed = 1`
            - final update involves updating all vault accounts, indexes and removing assets from global state
            - we cannot be sure that endVaults would be called precisely at the endTime for each vault
            - therefore we must allow for some drift
            - as such, the check below cannot be implemented. 
         */
        //if(vault.endTime > 0 && block.timestamp >= vault.endTime) return (vaultAccount, distribution);
        
        /**note:
            - what about implementing the check with a buffer? 
            - e.g. if(vault.endTime > 0 && block.timestamp + 7 days >= vault.endTime)
            - this would allow for some drift, but not too much

            smart over/under updates (?)
            - under: update distri to vault.Endtime and update the vault indexes till endTime
            - over: update distri to block.timestamp and update the vault indexes till endTime
         */

        
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
        DataTypes.Vault memory vault, DataTypes.VaultAccount memory vaultAccount_, DataTypes.Distribution memory distribution_) internal returns (DataTypes.UserAccount memory, DataTypes.VaultAccount memory, DataTypes.Distribution memory) {
        
        // get updated vaultAccount and distribution
        (DataTypes.VaultAccount memory vaultAccount, DataTypes.Distribution memory distribution) = _updateVaultAccount(vault, vaultAccount_, distribution_);
        
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
        uint256 numOfDistributions = activeDistributions.length;
        
        // update each user account, looping thru distributions
        for (uint256 i; i < numOfDistributions; ++i) {
             
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


    ///@dev cache vault and user structs from storage to memory. checks that vault exists and hasn't ended, else reverts.
    function _cache(bytes32 vaultId, address onBehalfOf) internal view returns(DataTypes.User memory, DataTypes.Vault memory) {
        // ensure vault exists
        DataTypes.Vault memory vault = vaults[vaultId];
        if(vault.creator == address(0)) revert NonExistentVault(vaultId);

        // get vault level user data
        DataTypes.User memory userVaultAssets = users[onBehalfOf][vaultId];

        return (userVaultAssets, vault);
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

        if(numOfVaults != userAddresses.length) revert InvalidArray();

        // for each vault
        for(uint256 i; i < numOfVaults; ++i) {
            
            bytes32 vaultId = vaultIds[i];

            // get vault + ensure it exists
            DataTypes.Vault memory vault = vaults[vaultId];
            if(vault.creator == address(0)) revert NonExistentVault(vaultId);

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

                //userVaultAssets.boostedRealmPoints = (userVaultAssets.stakedRealmPoints * vault.totalBoostFactor) / PRECISION_BASE;
                //userVaultAssets.boostedStakedTokens = (userVaultAssets.stakedTokens * vault.totalBoostFactor) / PRECISION_BASE;

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
     * @notice Updates the minimum realm points required for staking
     * @dev Zero values are not accepted to prevent dust attacks
     * @param newAmount The new minimum realm points required
     * @custom:throws InvalidAmount if newAmount is zero
     * @custom:emits MinimumRealmPointsUpdated when requirement is changed
     */
    function updateMinimumRealmPoints(uint256 newAmount) external onlyOwner {
        if(newAmount == 0) revert InvalidAmount();
        
        uint256 oldAmount = MINIMUM_REALMPOINTS_REQUIRED;
        MINIMUM_REALMPOINTS_REQUIRED = newAmount;

        emit MinimumRealmPointsUpdated(oldAmount, newAmount);
    }

    /**
     * @notice Updates the cooldown duration for vaults
     * @dev Zero values are accepted. New duration can be less or more than current value
     * @param newDuration The new cooldown duration to set
     */
    function updateVaultCooldown(uint256 newDuration) external onlyOwner {
        
        emit VaultCooldownDurationUpdated(VAULT_COOLDOWN_DURATION, newDuration);
        
        VAULT_COOLDOWN_DURATION = newDuration;
    }


    /**
     * @notice Sets up a new token distribution schedule
     * @dev Can only be called by contract owner. Distribution must not already exist.
     * @dev Distribution ID 0 is reserved for staking power and is the only ID allowed to have indefinite endTime
     * @param distributionId Unique identifier for this distribution (0 reserved for staking power)
     * @param distributionStartTime Timestamp when distribution begins, must be in the future
     * @param distributionEndTime Timestamp when distribution ends (0 allowed only for ID 0)
     * @param emissionPerSecond Rate of token emissions per second (must be > 0)
     * @param tokenPrecision Decimal precision for the distributed token (must be > 0)
     * @custom:throws ZeroEmissionRate if emission rate is 0
     * @custom:throws ZeroTokenPrecision if token precision is 0
     * @custom:throws InvalidStartTime if start time is not in the future
     * @custom:throws InvalidDistributionEndTime if end time is not after start time
     * @custom:throws InvalidEndTime if non-zero ID has indefinite end time
     * @custom:throws DistributionAlreadySetup if distribution with ID already exists
     * @custom:emits DistributionCreated when distribution is successfully created
     */
    function setupDistribution(uint256 distributionId, uint256 distributionStartTime, uint256 distributionEndTime, uint256 emissionPerSecond, uint256 tokenPrecision) external onlyOwner {
        if (emissionPerSecond == 0) revert ZeroEmissionRate();
        if (tokenPrecision == 0) revert ZeroTokenPrecision();

        if (distributionStartTime <= block.timestamp) revert InvalidStartTime();
        if (distributionEndTime <= distributionStartTime) revert InvalidDistributionEndTime();

        // only staking power can have indefinite endTime
        if(distributionId > 0 && distributionEndTime == 0) revert InvalidEndTime();

        // lazy load startTime, instead of entire struct
        DataTypes.Distribution storage distributionPointer = distributions[distributionId]; 
        
        // check if fresh id
        if(distributionPointer.startTime > 0) revert DistributionAlreadySetup();
            
        // Initialize struct
        DataTypes.Distribution memory distribution = DataTypes.Distribution({
            distributionId: distributionId,
            TOKEN_PRECISION: tokenPrecision,
            endTime: distributionEndTime,
            startTime: distributionStartTime,
            emissionPerSecond: emissionPerSecond,
            index: 0,                    // Initialize explicitly
            totalEmitted: 0,            // Initialize explicitly
            lastUpdateTimeStamp: distributionStartTime
        });

        // update storage
        distributions[distributionId] = distribution;

        // update distribution tracking
        activeDistributions.push(distributionId);
        ++ totalDistributions;

        emit DistributionCreated(distributionId, distributionStartTime, distributionEndTime, emissionPerSecond, tokenPrecision);
    }

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
    function updateDistribution(uint256 distributionId, uint256 newStartTime, uint256 newEndTime, uint256 newEmissionPerSecond) external onlyOwner whenNotPaused {

        if(newStartTime == 0 && newEndTime == 0 && newEmissionPerSecond == 0) revert InvalidDistributionParameters(); 

        DataTypes.Distribution memory distribution = distributions[distributionId];
        
        // Check distribution exists
        if(distribution.startTime == 0) revert NonExistentDistribution();

        if(block.timestamp >= distribution.endTime) revert DistributionEnded();
        
        _updateDistributionIndex(distribution);

        // startTime modification
        if(newStartTime > 0) {
            // Cannot update if distribution has already started
            if(block.timestamp >= distribution.startTime) revert DistributionStarted();
            
            // newStartTime must be a future time
            if(newStartTime <= block.timestamp) revert InvalidStartTime();

            distribution.startTime = newStartTime;
        }
        
        // endTime modification
        if(newEndTime > 0) {

            // cannot be in the past
            if(newEndTime < block.timestamp) revert InvalidEndTime();

            // If only endTime is being updated, ensure it's after existing startTime
            if(newStartTime == 0 && newEndTime <= distribution.startTime) revert InvalidDistributionEndTime();
            
            // If both times are being updated, ensure end is after start
            if(newStartTime > 0 && newEndTime <= newStartTime) revert InvalidDistributionEndTime();

            // update endTime
            distribution.endTime = newEndTime;
        }

        // emissionPerSecond modification 
        if(newEmissionPerSecond > 0) distribution.emissionPerSecond = newEmissionPerSecond;

        distributions[distributionId] = distribution;

        emit DistributionUpdated(distributionId, distribution.startTime, distribution.endTime, distribution.emissionPerSecond);
    }


    /**
     * @notice Immediately ends a distribution
     * @param distributionId ID of the distribution to end
     * @custom:throws NonExistentDistribution if distribution doesn't exist
     * @custom:throws DistributionEnded if distribution has already ended
     * @custom:emits DistributionUpdated when distribution is ended
     */
    function endDistributionImmediately(uint256 distributionId) external onlyOwner whenNotPaused {
        DataTypes.Distribution memory distribution = distributions[distributionId];
        
        if(distribution.startTime == 0) revert NonExistentDistribution();
        if(block.timestamp >= distribution.endTime) revert DistributionEnded();
        
        _updateDistributionIndex(distribution);
        
        distribution.endTime = block.timestamp;
        distributions[distributionId] = distribution;

        emit DistributionUpdated(distributionId, distribution.startTime, distribution.endTime, distribution.emissionPerSecond);
    }

    /**
     * @notice Updates the rewards vault address
     * @dev Only callable by owner when contract is not paused
     * @param newRewardsVault The address of the new rewards vault contract
     * @custom:throws InvalidAddress if newRewardsVault is zero address
     * @custom:emits RewardsVaultSet when vault address is updated
     */
    function setRewardsVault(address newRewardsVault) external onlyOwner whenNotPaused {
        if(newRewardsVault == address(0)) revert InvalidAddress();       //note: what about setting to 0 to disable the rewards vault?

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
        if(stakedNfts == 0 && stakedTokens == 0) revert UserHasNothingStaked(vaultId, onBehalfOf);
       
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