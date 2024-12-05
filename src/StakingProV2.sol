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

    uint256 public NFT_MULTIPLIER = 10; //note 

    // pool emergency state
    bool public isFrozen;

    // pool data
    DataTypes.PoolAccounting public pool;

    // creation nft requirement
    uint256 public creationNftsRequired = 5;

//-------------------------------mappings--------------------------------------------

    // just stick staking power as 0x0?
    mapping (bytes32 token => TokenData token) public tokens;       // token address as bytes32 for handling non-EVM tokens

    // vault base attributes
    mapping(bytes32 vaultId => DataTypes.Vault vault) public vaults;

    // for independent reward tracking              
    mapping (bytes32 vaultId => mapping(bytes32 token => DataTypes.VaultAccount vaultAccount)) public vaultAccounts;

    // generic userInfo wrt to vault 
    mapping(address user => mapping (bytes32 vaultId => DataTypes.User user)) public users;
    // Tracks rewards accrued for each user: per token type
    mapping(address user => mapping (bytes32 vaultId => mapping (bytes32 token => DataTypes.UserAccount userAccount))) public userAccounts;

//-------------------------------constructor------------------------------------------

    constructor(address registry, address rewardsVault, uint256 startTime_, uint256 emissionPerSecond, address owner) payable Ownable(owner) {

        // sanity check input data: time, period, rewards
        require(owner > address(0), "Zero address");
        require(startTime_ > block.timestamp, "Invalid startTime");
        require(emissionPerSecond > 0, "emissionPerSecond = 0");

        // interfaces: supporting contracts
        NFT_REGISTRY = INftRegistry(registry);              
        REWARDS_VAULT = IRewardsVault(rewardsVault);    

        // instantiate data
        DataTypes.PoolAccounting memory pool_;

        // set startTime & pool.lastUpdateTimeStamp
        startTime = pool_.lastUpdateTimeStamp = startTime_;
        endTime = startTime_ + duration;   

        pool_.emissionPerSecond = emissionPerSecond;

        // update storage
        pool = pool_;

        emit DistributionUpdated(pool_.emissionPerSecond, startTime);
    }


//-------------------------------external---------------------------------------------

    /**
      * @notice Creates empty vault
      * @dev Nfts must be committed to create vault. Creation NFTs are locked to create vault
      * 
     */
    function createVault(address onBehalfOf, uint256[] calldata tokenIds, DataTypes.Fees calldata fees) external whenStarted whenNotPaused {

        // must commit unstaked NFTs to create vaults: these do not count towards stakedNFTs
        uint256 incomingNfts = tokenIds.length;
        if(incomingNfts != creationNftsRequired) revert Errors.IncorrectCreationNfts();
        
        for (uint256 i = 0; i < creationNftsRequired; i++) {

            (address owner, bytes32 nftVaultId) = NFT_REGISTRY.nfts(tokenIds[i]);
            
            if(owner != onBehalfOf) revert Errors.IncorrectNftOwner(tokenIds[i]);
            if(nftVaultId != bytes32(0)) revert Errors.NftAlreadyStaked(tokenIds[i]);
        }

        //note: MOCA stakers must receive ≥50% of all rewards
        uint256 totalFeeFactor = fees.creatorFeeFactor + fees.nftFeeFactor + fees.realmPointFeeFactor;
        require(totalFeeFactor <= 50, "Cannot exceed 50%");

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



//-------------------------------internal-------------------------------------------

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
        (uint256 nextPoolIndex, uint256 currentTimestamp, uint256 emittedRewards) = _calculatePoolIndex(pool_.stakingPowerIndex, pool_.emissionPerSecond, pool_.lastUpdateTimeStamp, pool.totalAllocPoints);

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

        uint256 currentTimestamp;
        if(endTime > 0){
            currentTimestamp = block.timestamp > endTime ? endTime : block.timestamp;
        }
        else {
            currentTimestamp = block.timestamp;
        }

        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;
        
        uint256 emittedRewards = emissionPerSecond * timeDelta;

        uint256 nextPoolIndex = ((emittedRewards * TOKEN_PRECISION) / totalBalance) + currentPoolIndex;
    
        return (nextPoolIndex, currentTimestamp, emittedRewards);
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