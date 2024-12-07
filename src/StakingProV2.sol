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
    uint256 boostedStakedTokens;
    uint256 boostedRealmPoints;

    // pool emergency state
    bool public isFrozen;

    //------- modifiables -------------

    // creation nft requirement
    uint256 public creationNftsRequired = 5;

    uint256 public NFT_MULTIPLIER = 10; //note: wrangle as pct; differing precision base

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
 
        // check if vault exists + cache user & vault structs to memory
       (DataTypes.User memory userGlobal, DataTypes.User memory userVaultAssets, DataTypes.Vault memory vault_) = _cache(vaultId, onBehalfOf);

        // update all indexes and book all prior rewards [user and all distributions]
       (DataTypes.UserInfo memory userInfo, DataTypes.Vault memory vault) = _updateUserIndexes(onBehalfOf, userInfo_, vault_);

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

        // update vaultIndexes: book prior rewards, based on prior alloc points 
        _updateDistributionIndexes();

        // update pool Accounts - for active vaults
        uint256 numOfActiveVaults = activeVaults.length;
        if (numOfActiveVaults > 0){

            for (uint256 i; i < activeVaults.length; i++) {
                
                // get currentVaultIndex
                DataTypes.VaultData memory vault = vaults[activeVaults[i]];
                
                // update corresponding pool account
                poolAccounts[poolId][vault.vaultId].poolIndex = vault.index; 

                // nft index ?

            }
        }



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

//-------------------------------internal-------------------------------------------

    /**
        stake() -> _updateUserIndexes -> updateVault -> updateDistributions
        create() -> updateDistributions [no pool created, so no userIndexes for it either]

        stakedMoca -> token rewards, 
        stakedRP -> Staking power rewards
     */

    function _updateDistributionIndexes() internal {
        if(activeVaults.length == 0) revert;

        uint256 numOfDistributions = activeDistributions.length;

        for(uint256 i; i < numOfDistributions; ++i) {

            DataTypes.VaultData memory distribution = distributions[activeDistributions[i]];
            _updateVaultIndex(distribution);

            // update storage
            distributions[activeDistributions[i]] = distribution;
        }

    }

    function _updateDistributionIndex(DataTypes.VaultData memory vault) internal return(DataTypes.VaultData memory) {
        
        // already updated: return
        if(vault.lastUpdateTimeStamp == block.timestamp) {
            // do nothing
        }
        
        uint256 nextVaultIndex;
        uint256 currentTimestamp;
        uint256 emittedRewards;

        // staking power
        if(vault.chainId == 0) {
            
            // staked RP is the base of Staking power rewards
            (nextVaultIndex, currentTimestamp, emittedRewards) = _calculateVaultIndex(vault.index, vault.emissionPerSecond, vault.lastUpdateTimeStamp, boostedRealmPoints, vault.TOKEN_PRECISION);

        } else {

            // staked Moca is the base of token rewards
            (nextVaultIndex, currentTimestamp, emittedRewards) = _calculateVaultIndex(vault.index, vault.emissionPerSecond, vault.lastUpdateTimeStamp, boostedStakedTokens, vault.TOKEN_PRECISION);
        }

        if(nextVaultIndex != vault.index) {
            
            // prev timestamp, oldIndex, newIndex: emit prev timestamp since you know the currentTimestamp as per txn time
            // emit VaultIndexUpdated(pool_.lastUpdateTimeStamp, pool_.index, nextPoolIndex); note: update event

            vault.index = nextVaultIndex;
            vault.totalEmitted += emittedRewards; 
            vault.lastUpdateTimeStamp = block.timestamp;
        }

        return vault;
    }

    /**
     * @dev Calculates latest pool index. Pool index represents accRewardsPerAllocPoint since startTime.
     * @param currentRewardIndex Latest reward index as per previous update
     * @param emissionPerSecond Reward tokens emitted per second (in wei)
     * @param lastUpdateTimestamp Time at which previous update occurred
     * @param totalBalance Total allocPoints of the pool 
     * @return nextPoolIndex: Updated pool index, 
               currentTimestamp: either lasUpdateTimestamp or block.timestamp, 
               emittedRewards: rewards emitted from lastUpdateTimestamp till now
     */
    function _calculateVaultIndex(uint256 currentVaultIndex, uint256 emissionPerSecond, uint256 lastUpdateTimestamp, uint256 totalBalance, uint256 precision) internal view returns (uint256, uint256, uint256) {
        if (
            emissionPerSecond == 0                           // 0 emissions. no rewards setup.
            || totalBalance == 0                             // nothing has been staked
            || lastUpdateTimestamp == block.timestamp        // vaultIndex already updated
            || lastUpdateTimestamp > endTime                 // distribution has ended
        ) {

            return (currentVaultIndex, lastUpdateTimestamp, 0);                       
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

        uint256 nextVaultIndex = ((emittedRewards * precision) / totalBalance) + currentVaultIndex;
    
        return (nextVaultIndex, currentTimestamp, emittedRewards);
    }


    ///@dev cache vault and user structs from storage to memory. checks that vault exists, else reverts.
    function _cache(bytes32 vaultId, address onBehalfOf) internal view returns(DataTypes.User memory, DataTypes.User memory, DataTypes.Vault memory) {
        
        // ensure vault exists
        DataTypes.Vault memory vault = vaults[vaultId];
        if(vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);

        // get global and vault level user data
        DataTypes.User memory userGlobal = users[onBehalfOf];
        DataTypes.User memory userVaultAssets = usersVaultAssets[onBehalfOf][vaultId];

        return (userGlobal, userVaultAssets, vault);
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

    ///@dev Generate a poolId. keccak256 is cheaper than using a counter with a SSTORE, even accounting for eventual collision retries.
    function _generatePoolId(uint256 salt, address onBehalfOf) internal view returns (bytes32) {
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