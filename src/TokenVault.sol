// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";


// this is just a container. all calcs and tracking is on staking contract
contract TokenVault is OApp, Pausable, AccessControl, Ownable2Step {
    using SafeERC20 for IERC20;

    address public pool;
    uint32 public immutable srcEid; //    LZ's eid for where this contract is deployed

    // roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MONEY_MANAGER_ROLE = keccak256("MONEY_MANAGER_ROLE");
    
    struct Distribution {
        uint32 dstEid;  // LZ eid
        bytes32 tokenAddress;
        
        uint256 totalClaimed;
        uint256 totalDeposited;
    }

    struct AddressBook {
        address evm;
        bytes32 solana;        
        //....
    }

    mapping(uint256 distributionId => Distribution distribution) public distributions;

    mapping(address users => AddressBook addressBook) public users;

    // events
    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    event RecoveredTokens(address indexed token, address indexed target, uint256 indexed amount);
    event PoolSet(address indexed oldPool, address indexed newPool);

    // errors
    error IncorrectToken();
    error InsufficientDeposits();
    error InsufficientGas();

    constructor(address moneyManager, address admin, address endpoint, address owner) OApp(endpoint, owner) Ownable(owner) {

        _grantRole(MONEY_MANAGER_ROLE, moneyManager);
        _grantRole(ADMIN_ROLE, admin);
    }


    /**
     * @notice Deposit rewards into the vault
     * @param from Address from which rewards are to be pulled
     * @param amount Rewards amount (in wei)
     */
    function deposit(uint256 distributionId, address token, uint256 amount, address from) onlyRole(MONEY_MANAGER_ROLE) external {
        require(from != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");

        // check
        Distribution memory distribution = distributions[distributionId];
        if(token != bytes32ToAddress(distribution.tokenAddress)) revert IncorrectToken();

        // update
        distribution.totalDeposited += amount;
        
        // update storage
        distributions[distributionId] = distribution;

        emit Deposit(from, amount);

        IERC20(token).safeTransferFrom(from, address(this), amount);
    }

    /**
     * @notice Withdraw rewards from the vault
     * @param to Address from which rewards are to be pulled
     * @param amount Rewards amount (in wei)
     */
    function withdraw(uint256 distributionId, address token, uint256 amount, address to) onlyRole(MONEY_MANAGER_ROLE) external {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");

        Distribution memory distribution = distributions[distributionId];
        if(token != bytes32ToAddress(distribution.tokenAddress)) revert IncorrectToken();

        distribution.totalDeposited -= amount;
        
        // update storage
        distributions[distributionId] = distribution;

        emit Withdraw(to, amount);

        IERC20(token).safeTransfer(to, amount);
    }

    function payRewards(uint256 distributionId, uint32 dstEid, address to, uint256 amount) external payable virtual {}


    /**
     * @notice Called by Staking Pool contract to transfer rewards to users
     * @param to Address to which rewards are to be paid out
     * @param amount Reward amount (expressed in the token's precision)
     */
    function payRewards(uint256 distributionId, address to, uint256 amount) external payable virtual {
        require(msg.sender == pool, "Only Pool");

        Distribution memory distribution = distributions[distributionId];
        
        // check balance
        uint256 available = distribution.totalDeposited - distribution.totalClaimed;
        if(available < amount) revert InsufficientDeposits();

        // update balance
        distribution.totalClaimed += amount;

        // update storage
        distributions[distributionId] = distribution;

        // emit    
        
        // is local
        if(distribution.dstEid == srcEid){

            AddressBook memory user = users[to];
            address receiver = user.evm == address(0) ? to : user.evm;

            // get address + transfer
            address token = bytes32ToAddress(distribution.tokenAddress);
            IERC20(token).safeTransfer(receiver, amount); 
        }

        // is it solana
        else if (distribution.dstEid == 30168){

            // create options
            bytes memory options;
            //options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

            // craft payload: beneficiary address + amount
            bytes memory payload = abi.encode(users[to].solana, amount);

            // check gas needed
            MessagingFee memory fee = _quote(distribution.dstEid, payload, options, false);
            if(msg.value < fee.nativeFee) revert InsufficientGas();
            
            // MessagingFee: Fee struct containing native gas and ZRO token
            // returns MessagingReceipt struct
            _lzSend(distribution.dstEid, payload, options, fee, payable(msg.sender));

        
        // is it x-chain evm
        } else { 

            AddressBook memory user = users[to];
            address receiver = user.evm == address(0) ? to : user.evm;
            
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