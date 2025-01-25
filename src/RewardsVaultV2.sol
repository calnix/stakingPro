// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./RewardsVaultV1.sol";

// LZ imports
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
//import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

// ownable solely for LZ
contract RewardsVaultV2 is RewardsVaultV1, OApp, Ownable2Step {
    using SafeERC20 for IERC20;
    
    // LZ constants
    uint256 public constant SOLANA_EID = 30168;
    
//------- constructor ----------------------------
    constructor(address moneyManager, address admin, address endpoint, address owner, address pool) 
        RewardsVaultV1(moneyManager, admin, owner, pool) OApp(endpoint, owner) Ownable(owner) {
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
    function payRewards(uint256 distributionId, address to, uint256 amount) external payable override onlyRole(POOL_ROLE) {
        // no need for input checks, as this is called by pool

        // get distribution + user
        Distribution memory distribution = distributions[distributionId];
        UserAddresses memory user = users[to];
        
        // check balance
        uint256 available = distribution.totalDeposited - distribution.totalClaimed;
        if(available < amount) revert Errors.InsufficientDeposits();

        // update claimed
        distribution.totalClaimed += amount;

        // update storage
        distributions[distributionId] = distribution;

        // local: transfer to receiver
        if(distribution.dstEid == LOCAL_EID){
            
            // get receiver + token addresses
            address receiver = user.evmAddress == address(0) ? to : user.evmAddress;
            address token = bytes32ToAddress(distribution.tokenAddress);

            // update storage
            paidOut[to][addressToBytes32(receiver)][distribution.tokenAddress] += amount;

            emit PayRewards(distributionId, to, addressToBytes32(receiver), amount);
 
            // transfer
            IERC20(token).safeTransfer(receiver, amount); 
        }

        // if it is solana
        else if (distribution.dstEid == SOLANA_EID){

            // update storage
            paidOut[to][user.solanaAddress][distribution.tokenAddress] += amount;
            emit PayRewards(distributionId, to, user.solanaAddress, amount);

            // ------------------------ LZ ----------------------------

            // create options
            bytes memory options;
            //options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

            // craft payload: beneficiary address + amount
            bytes memory payload = abi.encode(distribution.tokenAddress, amount, user.solanaAddress);

            // check gas needed
            MessagingFee memory fee = _quote(distribution.dstEid, payload, options, false);
            if(msg.value < fee.nativeFee) revert Errors.InsufficientGas();
            
            // MessagingFee: Fee struct containing native gas and ZRO token
            // returns MessagingReceipt struct
            _lzSend(distribution.dstEid, payload, options, fee, payable(msg.sender));

        // we assume all else is x-chain evm
        } else { 
            
            // get user address
            address receiver = user.evmAddress == address(0) ? to : user.evmAddress;

            // update storage
            paidOut[to][addressToBytes32(receiver)][distribution.tokenAddress] += amount;
            emit PayRewards(distributionId, to, addressToBytes32(receiver), amount);

            // ------------------------ LZ ----------------------------

            // create options
            bytes memory options;
            //options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

            // craft payload: beneficiary address + amount
            bytes memory payload = abi.encode(distribution.tokenAddress, amount, receiver);

            // check gas needed
            MessagingFee memory fee = _quote(distribution.dstEid, payload, options, false);
            if(msg.value < fee.nativeFee) revert Errors.InsufficientGas();
            
            // MessagingFee: Fee struct containing native gas and ZRO token
            // returns MessagingReceipt struct
            _lzSend(distribution.dstEid, payload, options, fee, payable(msg.sender));
        }
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
     * @param payload message payload being received
     * @custom:anon-param origin A struct containing information about where the packet came from.
     * @custom:anon-param guid: A global unique identifier for tracking the packet.
     * @custom:anon-param executor: Executor address as specified by the OApp.
     * @custom:anon-param options: Any extra data or options to trigger on receipt.
     */
    function _lzReceive(Origin calldata origin, bytes32 /*guid*/, bytes calldata payload, address /*executor*/, bytes calldata /*options*/) internal override {
    
        //note: distributionId != 0 already checked in remote

        // deposits made on remote vaults
        (uint256 distributionId, uint256 amount, uint256 isDeposit) = abi.decode(payload, (uint256, uint256, uint256));
        
        // deposits made on remote vaults
        if(isDeposit == 1){

            distributions[distributionId].totalDeposited += amount;
        }
        
        // withdrawals made on remote vaults
        else {
            distributions[distributionId].totalDeposited -= amount;
        }

        emit Deposit(distributionId, origin.srcEid, msg.sender, amount);
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

} 