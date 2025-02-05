// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./Events.sol";
import "./Errors.sol";

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// this is just a container. all calcs and tracking is on staking contract
contract RewardsVaultV1 is Pausable, AccessControl {
    using SafeERC20 for IERC20;

    // roles
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");                // only pause  
    bytes32 public constant MONEY_MANAGER_ROLE = keccak256("MONEY_MANAGER_ROLE");    // withdraw/deposit
    
    // LZ constants
    uint32 public constant LOCAL_EID = 30184; // base mainnet

    // structs
    struct Distribution {
        uint32 dstEid;           // LZ eid: proxy for chainId
        bytes32 tokenAddress;    // token address encoded as bytes32

        uint256 totalRequired;   // updated by pool: for reference wrt deposit/withdraw
        uint256 totalClaimed;
        uint256 totalDeposited;
    }

    struct UserAddresses {
        address evmAddress;     
        bytes32 solanaAddress;        
    }

//-------------------------------mappings--------------------------------------------
    
    mapping(address user => UserAddresses userAddresses) public users;
    mapping(uint256 distributionId => Distribution distribution) public distributions;
    
    // bytes32 used for receiver and token addresses to account for future non-evm chains
    mapping(address to => mapping(bytes32 receiver => mapping(bytes32 token => uint256 amount))) public paidOut;
        
//------- constructor ----------------------------------------------------------
    constructor(address moneyManager, address monitor, address owner, address pool) {

        // access control
        _grantRole(DEFAULT_ADMIN_ROLE, owner);              // default admin role for all roles
        
        _grantRole(POOL_ROLE, pool);                        // pool contract
        _grantRole(MONITOR_ROLE, monitor);                  // risk monitoring script
        _grantRole(MONEY_MANAGER_ROLE, moneyManager);
    }

//------- external functions -----------------------------------------------------
    
    /*//////////////////////////////////////////////////////////////
                              POOL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets up a new distribution for tracking rewards
     * @dev Only callable by POOL_ROLE. Distribution ID 0 is reserved for staking power.
     * @param distributionId Unique identifier for this distribution
     * @param dstEid LayerZero endpoint ID for the destination chain (0 for local chain)
     * @param tokenAddress The token address for this distribution encoded as bytes32
     */
    function setupDistribution(uint256 distributionId, uint32 dstEid, bytes32 tokenAddress, uint256 totalRequired) external virtual onlyRole(POOL_ROLE) {
        // POOL ensures that:
        //  distributionId is > 0
        //  tokenAddress is not BYTES32(0)
        //  dstEid is > 0

        Distribution memory distribution = distributions[distributionId];
            distribution.dstEid = dstEid;
            distribution.tokenAddress = tokenAddress;
            distribution.totalRequired = totalRequired;

        // sanity check: will revert if address is not a token contract
        IERC20(bytes32ToAddress(tokenAddress)).balanceOf(address(this));

        // update
        distributions[distributionId] = distribution;

        emit DistributionCreated(distributionId, dstEid, tokenAddress);
    }

    /**
     * @notice Updates the total required for a distribution
     * @dev Only callable by pool
     * @param distributionId The ID of the distribution to update
     * @param newTotalRequired The new total required amount
     */
    function updateDistribution(uint256 distributionId, uint256 newTotalRequired) external virtual onlyRole(POOL_ROLE) {
        Distribution storage distributionPointer = distributions[distributionId];
        distributionPointer.totalRequired = newTotalRequired;
    }

    /**
     * @notice Ends a distribution immediately
     * @dev Only callable by pool
     * @param distributionId The ID of the distribution to end
     */
    function endDistributionImmediately(uint256 distributionId, uint256 totalEmitted) external virtual onlyRole(POOL_ROLE) {
        Distribution storage distributionPointer = distributions[distributionId];
        distributionPointer.totalRequired = totalEmitted;
        emit DistributionEnded(distributionId, totalEmitted);
    }

    /**
     * @notice Transfers rewards to users, handling both local and cross-chain distributions
     * @dev Only callable by the Staking Pool contract. Handles three cases:
     *      1. Local transfers using direct ERC20 transfer
     *      2. Solana transfers using LayerZero messaging
     *      3. Other EVM chain transfers using LayerZero messaging
     * @param distributionId The ID of the distribution to pay rewards from
     * @param to Address of the user receiving rewards
     * @param amount Reward amount (expressed in the token's precision)
     */
    function payRewards(uint256 distributionId, uint256 amount, address to) external payable virtual onlyRole(POOL_ROLE) {
        // no need for input checks, as this is called by pool

        // get distribution + user
        Distribution memory distribution = distributions[distributionId];
        UserAddresses memory user = users[to];

        // check balance
        uint256 available = distribution.totalDeposited - distribution.totalClaimed;
        if(available < amount) revert Errors.InsufficientDeposits();

        // update claimed
        distribution.totalClaimed += amount;

        // get receiver + token addresses
        address receiver = user.evmAddress == address(0) ? to : user.evmAddress;
        address token = bytes32ToAddress(distribution.tokenAddress);

        // update storage
        distributions[distributionId] = distribution;
        paidOut[to][addressToBytes32(receiver)][distribution.tokenAddress] += amount;
    
        emit PayRewards(distributionId, to, addressToBytes32(receiver), amount);
 
        // transfer
        IERC20(token).safeTransfer(receiver, amount); 
    }

    /*//////////////////////////////////////////////////////////////
                              MONEY_MANAGER
    //////////////////////////////////////////////////////////////*/

    /** 
     * @notice Deposits rewards into the vault for a specific distribution
     * @dev Only callable by accounts with MONEY_MANAGER_ROLE. Distribution ID 0 is reserved for staking power.
     * @param distributionId The ID of the distribution to deposit rewards for
     * @param amount Amount of rewards to deposit (in wei)
     * @param from Address from which rewards will be pulled
     */
    function deposit(uint256 distributionId, uint256 amount, address from) external onlyRole(MONEY_MANAGER_ROLE) {
        if(distributionId == 0) revert Errors.InvalidDistributionId();
        if(from == address(0)) revert Errors.InvalidAddress();
        if(amount == 0) revert Errors.InvalidAmount();
        
        // sanity checks
        Distribution memory distribution = distributions[distributionId];
        // incorrect distribution Id: only local deposits
        if(distribution.dstEid != LOCAL_EID) revert Errors.CallDepositOnRemote();
        // distribution must be setup
        if(distribution.tokenAddress == bytes32(0)) revert Errors.DistributionNotSetup();
        
        // check if excess: allow for partial deposits
        if(distribution.totalRequired < distribution.totalDeposited + amount) revert Errors.ExcessiveDeposit();
        
        // update + storage
        distribution.totalDeposited += amount;
        distributions[distributionId] = distribution;

        // local: transfer from sender
        address token = bytes32ToAddress(distribution.tokenAddress);
        IERC20(token).safeTransferFrom(from, address(this), amount);

        emit Deposit(distributionId, distribution.dstEid, from, amount);
    }
    
    /**
     * @notice Withdraws rewards from the vault for a specific distribution
     * @dev Only callable by accounts with MONEY_MANAGER_ROLE. Distribution ID 0 is reserved for staking power.
     * @param distributionId The ID of the distribution to withdraw rewards from
     * @param amount Amount of rewards to withdraw (in wei)
     * @param to Address to which rewards will be sent
     */
    function withdraw(uint256 distributionId, uint256 amount, address to) external onlyRole(MONEY_MANAGER_ROLE) {
        if(distributionId == 0) revert Errors.InvalidDistributionId();
        if(to == address(0)) revert Errors.InvalidAddress();
        if(amount == 0) revert Errors.InvalidAmount();

        // check
        Distribution memory distribution = distributions[distributionId];
        if(distribution.tokenAddress == bytes32(0)) revert Errors.DistributionNotSetup();
        
        // check if enough
        uint256 remaining = distribution.totalRequired - distribution.totalClaimed;
        if(remaining < amount) revert Errors.InsufficientDeposits();

        // update + storage
        distribution.totalClaimed += amount;
        distributions[distributionId] = distribution;

        // local: transfer to receiver
        address token = bytes32ToAddress(distribution.tokenAddress);
        IERC20(token).safeTransfer(to, amount);

        emit Withdraw(distributionId, distribution.dstEid, to, amount);
    }

//------------------------------- risk -------------------------------------------------------

    /**
     * @notice Pause pool. Cannot pause once frozen
     */
    function pause() external whenNotPaused onlyRole(MONITOR_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause pool. Cannot unpause once frozen
     */
    function unpause() external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

//------------------------------- pure ---------------------------------

    function addressToBytes32(address addr) public pure returns(bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 bytes32_) public pure returns(address) {
        return address(uint160(uint256(bytes32_)));
    }


} 
    



/**
    Setup a distribution
    - deposit required into here
    - setUpDistribution on pool
    
    - should setUpDistri on pool sanity check tokenVault?
    - yes, cos we can have multiple distributions, for the same token.

    LAYERZERO
    - isSupportedEid: https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
 */