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

//-------------------------------mappings-------------------------------------------

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

//-------------------------------constructor-------------------------------------------

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


//-------------------------------external-------------------------------------------

}