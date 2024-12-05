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

    INftRegistry public immutable NFT_REGISTRY;
    IRewardsVault public immutable REWARDS_VAULT;

    // times
    uint256 public immutable startTime;

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


}