// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";


// this is just a container. all calcs and tracking is on staking contract
contract RewardsVault is OApp, Pausable, AccessControl, Ownable2Step {
    using SafeERC20 for IERC20;

    address public pool;
    uint32 public immutable srcEid; //    LZ's eid for where this contract is deployed
    uint256 public immutable SOLANA_EID = 30168;

    // roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MONEY_MANAGER_ROLE = keccak256("MONEY_MANAGER_ROLE");
    
    // structs
    struct Distribution {
        uint32 dstEid;          // LZ eid: proxy for chainId. if zero, assumed to be local
        bytes32 tokenAddress;    // token address encoded as bytes32
        
        uint256 total;           // should be set by pool
        uint256 claimed;
        uint256 deposited;
    }

    struct AddressBook {
        address evmAddress;
        bytes32 solanaAddress;        
        //....
    }

    mapping(address user => AddressBook addressBook) public users;
    mapping(uint256 distributionId => Distribution distribution) public distributions;
    
//------- events --------------------------------
    event Deposit(uint256 distributionId, uint32 dstEid, address indexed from, uint256 amount);
    event Withdraw(uint256 distributionId, uint32 dstEid, address indexed to, uint256 amount);
    event RecoveredTokens(address indexed token, address indexed target, uint256 indexed amount);
    event PoolSet(address indexed oldPool, address indexed newPool);
    event DistributionSet(uint256 distributionId, uint32 dstEid, bytes32 tokenAddress);
    
    // evm and non-evm
    event PayRewards(uint256 distributionId, uint32 dstEid, address indexed to, address indexed receiver, uint256 amount);
    event PayRewards(uint256 distributionId, uint32 dstEid, address indexed to, bytes32 indexed receiver, uint256 amount);
    
//------- errors --------------------------------
    error IncorrectToken();
    error InsufficientDeposits();
    error InsufficientGas();
    error DistributionNotSetup();
    error ExcessiveWithdrawal();
    error ExcessiveDeposit();
//------- constructor ----------------------------
    constructor(address moneyManager, address admin, address endpoint, address owner) OApp(endpoint, owner) Ownable(owner) {

        _grantRole(MONEY_MANAGER_ROLE, moneyManager);
        _grantRole(ADMIN_ROLE, admin);
    }

//------- external functions ----------------------------
    
    // note: consider making this only callable by pool
    /**
     * @notice Sets up a new distribution for tracking rewards
     * @dev Only callable by admin role. Distribution ID 0 is reserved for staking power.
     * @param distributionId Unique identifier for this distribution
     * @param dstEid LayerZero endpoint ID for the destination chain (0 for local chain)
     * @param tokenAddress The token address for this distribution encoded as bytes32
     * @custom:throws "Invalid distributionId" if distributionId is 0
     * @custom:throws "Invalid tokenAddress" if tokenAddress is empty bytes32
     * @custom:emits DistributionSet when distribution is successfully created
     */
    function setUpDistribution(uint256 distributionId, uint32 dstEid, bytes32 tokenAddress, uint256 total) onlyRole(ADMIN_ROLE) external {
        require(distributionId > 0, "Invalid distributionId");  // 0 is reserved for staking power
        require(tokenAddress != bytes32(0), "Invalid tokenAddress");

        // update
        distributions[distributionId] = Distribution({
            dstEid: dstEid,                                 // if 0, assumed to be local
            tokenAddress: tokenAddress,
            total: total,
            claimed: 0,
            deposited: 0
        });

        emit DistributionSet(distributionId, dstEid, tokenAddress);
    }


    /**
     * @notice Deposits rewards into the vault for a specific distribution
     * @dev Only callable by accounts with MONEY_MANAGER_ROLE. Distribution ID 0 is reserved for staking power.
     * @param distributionId The ID of the distribution to deposit rewards for
     * @param amount Amount of rewards to deposit (in wei)
     * @param from Address from which rewards will be pulled
     * @custom:throws "Invalid distributionId" if distributionId is 0
     * @custom:throws "Invalid address" if from address is zero
     * @custom:throws "Invalid amount" if amount is 0
     * @custom:throws DistributionNotSetup if distribution is not initialized
     * @custom:throws ExcessiveDeposit if deposit would exceed distribution total
     * @custom:emits Deposit when rewards are successfully deposited
     */
    function deposit(uint256 distributionId, uint256 amount, address from) onlyRole(MONEY_MANAGER_ROLE) external {
        require(distributionId > 0, "Invalid distributionId");  // 0 is reserved for staking power
        require(from != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        
        // check
        Distribution memory distribution = distributions[distributionId];
        if(distribution.tokenAddress == bytes32(0)) revert DistributionNotSetup();

        // check if excess: allow for partial deposits
        if(distribution.total < distribution.deposited + amount) revert ExcessiveDeposit();
        
        // update
        distribution.deposited += amount;

        // local: transfer from sender
        if(distribution.dstEid == 0){
            address token = bytes32ToAddress(distribution.tokenAddress);
            IERC20(token).safeTransferFrom(from, address(this), amount);
        }
        
        // remote
        else {

            // do something?
            // call x-chain vault?
        }

        // update storage
        distributions[distributionId] = distribution;

        emit Deposit(distributionId, distribution.dstEid, from, amount);
    }


    /**
     * @notice Withdraws rewards from the vault for a specific distribution
     * @dev Only callable by accounts with MONEY_MANAGER_ROLE. Distribution ID 0 is reserved for staking power.
     * @param distributionId The ID of the distribution to withdraw rewards from
     * @param amount Amount of rewards to withdraw (in wei)
     * @param to Address to which rewards will be sent
     * @custom:throws "Invalid address" if to address is zero
     * @custom:throws "Invalid amount" if amount is 0
     * @custom:throws DistributionNotSetup if distribution is not initialized
     * @custom:throws InsufficientDeposits if withdrawal amount exceeds available balance
     * @custom:emits Withdraw when rewards are successfully withdrawn
     */
    function withdraw(uint256 distributionId, uint256 amount, address to) onlyRole(MONEY_MANAGER_ROLE) external {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");

        // check
        Distribution memory distribution = distributions[distributionId];
        if(distribution.tokenAddress == bytes32(0)) revert DistributionNotSetup();
        
        // check if enough
        uint256 remaining = distribution.total - distribution.claimed;
        if(remaining < amount) revert InsufficientDeposits();

        // update storage
        distribution.claimed += amount;
        
        // local: transfer to receiver
        if(distribution.dstEid == 0){
            address token = bytes32ToAddress(distribution.tokenAddress);
            IERC20(token).safeTransfer(to, amount);
        }

        // remote
        else {

            // do something?
            // call x-chain vault?
        }
        
        // update storage
        distributions[distributionId] = distribution;

        emit Withdraw(distributionId, distribution.dstEid, to, amount);
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
     * @custom:throws "Only Pool" if caller is not the pool contract
     * @custom:throws DistributionNotSetup if distribution is not initialized
     * @custom:throws InsufficientDeposits if reward amount exceeds available balance
     * @custom:throws InsufficientGas if msg.value is insufficient for cross-chain message fees
     * @custom:emits PayRewards(uint256,uint32,address,address,uint256) for local and EVM chain transfers
     * @custom:emits PayRewards(uint256,uint32,address,bytes32,uint256) for Solana transfers
     */
    function payRewards(uint256 distributionId, address to, uint256 amount) external payable virtual {
        require(msg.sender == pool, "Only Pool");

        Distribution memory distribution = distributions[distributionId];
        
        // check balance
        uint256 available = distribution.total - distribution.claimed;
        if(available < amount) revert InsufficientDeposits();

        // update balance
        distribution.claimed += amount;

        // update storage
        distributions[distributionId] = distribution;

        // get user struct
        AddressBook memory user = users[to];

        // local: transfer to receiver
        if(distribution.dstEid == 0){
            
            // get user address
            address receiver = user.evmAddress == address(0) ? to : user.evmAddress;

            // get token address
            address token = bytes32ToAddress(distribution.tokenAddress);

            emit PayRewards(distributionId, distribution.dstEid, to, receiver, amount);
 
            //transfer
            IERC20(token).safeTransfer(receiver, amount); 
        }

        // if it is solana
        else if (distribution.dstEid == SOLANA_EID){

            // create options
            bytes memory options;
            //options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

            // craft payload: beneficiary address + amount
            bytes memory payload = abi.encode(user.solanaAddress, amount);


            // check gas needed
            MessagingFee memory fee = _quote(distribution.dstEid, payload, options, false);
            if(msg.value < fee.nativeFee) revert InsufficientGas();
            
            // MessagingFee: Fee struct containing native gas and ZRO token
            // returns MessagingReceipt struct
            _lzSend(distribution.dstEid, payload, options, fee, payable(msg.sender));

            emit PayRewards(distributionId, distribution.dstEid, to, user.solanaAddress, amount);

        // we assume all else is x-chain evm
        } else { 

            // get user address
            address receiver = user.evmAddress == address(0) ? to : user.evmAddress;
            
            // create options
            bytes memory options;
            //options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

            // craft payload: beneficiary address + amount
            bytes memory payload = abi.encode(receiver, amount);

            // check gas needed
            MessagingFee memory fee = _quote(distribution.dstEid, payload, options, false);
            if(msg.value < fee.nativeFee) revert InsufficientGas();
            
            // MessagingFee: Fee struct containing native gas and ZRO token
            // returns MessagingReceipt struct
            _lzSend(distribution.dstEid, payload, options, fee, payable(msg.sender));

            emit PayRewards(distributionId, distribution.dstEid, to, receiver, amount);
        }
    }

    /**
     * @notice Set the address of the staking pool
     * @param newPool Address of pool contract
     */
    function setPool(address newPool) onlyRole(ADMIN_ROLE) external {
        require(newPool != address(0), "Invalid address");

        emit PoolSet(pool, newPool);
        pool = newPool;
    }

//------------------------------- recover ------------------------------
    
    /**
     * @notice Recover random tokens accidentally sent to the vault
     * @param tokenAddress Address of token contract
     * @param receiver Recepient of tokens 
     * @param amount Amount to retrieve
     */
    function recoverERC20(address tokenAddress, address receiver, uint256 amount) external onlyRole(ADMIN_ROLE) {
        //require(tokenAddress != address(REWARD_TOKEN), "Out-of-scope");
        
        IERC20(tokenAddress).safeTransfer(receiver, amount);
        emit RecoveredTokens(tokenAddress, receiver, amount);
    }


//------------------------------- pure ---------------------------------

    function addressToBytes32(address addr) public pure returns(bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 bytes32_) public pure returns(address) {
        return address(uint160(uint256(bytes32_)));
    }

//------------------------------- OWNABLE2STEP ---------------------------------

    /*//////////////////////////////////////////////////////////////
                              OWNABLE2STEP
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public override(Ownable, Ownable2Step) onlyOwner {
        Ownable2Step.transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal override(Ownable, Ownable2Step) {
        Ownable2Step._transferOwnership(newOwner);
    }

//------------------------------- LAYERZERO ---------------------------------

    /*//////////////////////////////////////////////////////////////
                               LAYERZERO
    //////////////////////////////////////////////////////////////*/


    /** 
     * @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @param to Address of beneficiary
     * @param amount Amount of tokens to be dispensed (expressed in its native precision)
     */
    function quote(bytes32 to, uint256 amount, uint32 dstEid) external view returns (uint256 nativeFee, uint256 lzTokenFee) {
        require(amount > 0, "Invalid amount");
        //require(to != , "Invalid address");
        
        // payload
        bytes memory payload = abi.encode(to, amount);

        // create options
        bytes memory options;
        //options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

        MessagingFee memory fee = _quote(dstEid, payload, options, false);
        return (fee.nativeFee, fee.lzTokenFee);
    }


    /**
     * @dev Override of _lzReceive internal fn in OAppReceiver.sol. The public fn lzReceive, handles param validation.
     * @param origin A struct containing information about where the packet came from.
     * @param guid A global unique identifier for tracking the packet.
     * @param payload message payload being received
     * @custom:anon-param address: Executor address as specified by the OApp.
     * @custom:anon-param bytes calldata: Any extra data or options to trigger on receipt.
     */
    function _lzReceive(Origin calldata origin, bytes32 guid, bytes calldata payload, address, bytes calldata) internal override {
        
        //note: do i want to implement receive?    

        // owner, tokendId
        //(address owner, uint256[] memory tokenIds) = abi.decode(payload, (address, uint256[]));

        //_unlock(owner, tokenIds);
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