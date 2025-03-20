// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./RewardsVaultV1.sol";

// LZ imports
import { Ownable2Step, Ownable } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";


// ownable solely for LZ
contract RewardsVaultV2 is RewardsVaultV1, OApp, Ownable2Step {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;
    
    // LZ
    uint256 public constant SOLANA_EID = 30168;
    uint128 public constant GAS_LIMIT = 90_000;
    uint128 public gasBuffer;

//------------------------------- constructor ----------------------------
    constructor(address moneyManager, address monitor, address owner, address pool, address endpoint) 
        RewardsVaultV1(moneyManager, monitor, owner, pool) OApp(endpoint, owner) Ownable(owner) {
    }

    /**
     * @notice Transfers rewards to users, handling both local and cross-chain distributions
     * @dev Only callable by the Staking Pool contract. Handles three cases:
     *      1. Local transfers using direct ERC20 transfer
     *      2. Solana transfers using LayerZero messaging
     *      3. Other EVM chain transfers using LayerZero messaging
     * @param distributionId The ID of the distribution to pay rewards from
     * @param staker Address of staker
     * @param amount Reward amount (expressed in the token's precision)
     */
    function payRewards(uint256 distributionId, uint256 amount, address staker) external payable override whenNotPaused onlyRole(POOL_ROLE) {
        // no need for input checks, as this is called by pool

        // get distribution + user
        Distribution memory distribution = distributions[distributionId];
        UserAddresses memory user = users[staker];
        
        // check balance
        uint256 balance = distribution.totalDeposited - distribution.totalClaimed;
        if(balance < amount) revert Errors.InsufficientBalance();

        // update claimed
        distribution.totalClaimed += amount;

        // get receiver + token addresses
        address receiver = user.evmAddress == address(0) ? staker : user.evmAddress;
        address token = bytes32ToAddress(distribution.tokenAddress);

        // update storage
        distributions[distributionId] = distribution;
        paidOut[staker][addressToBytes32(receiver)][distributionId] += amount;

        emit PayRewards(distributionId, staker, addressToBytes32(receiver), amount);

        // local: transfer to receiver
        if(distribution.dstEid == LOCAL_EID){
            // reject eth transfers for local
            if(msg.value > 0) revert Errors.PayableBlocked();
 
            // transfer
            IERC20(token).safeTransfer(receiver, amount); 
        }
        else { // we assume all else is x-chain evm
            
            // ------------------------ LZ ----------------------------

            // create options: dst gas needed for lzReceive execution on remote
            bytes memory options;
            options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: GAS_LIMIT + gasBuffer, _value: 0});

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

    function updateRemoteBalance(uint256 distributionId, uint256 amount, uint256 isDeposit) external onlyRole(MONEY_MANAGER_ROLE) {
        if(amount == 0) revert Errors.InvalidAmount();
        if(distributionId == 0) revert Errors.InvalidDistributionId();

        Distribution memory distribution = distributions[distributionId];
        if(distribution.dstEid == LOCAL_EID) revert Errors.InvalidOrigin();

        // deposits made on remote vaults
        if(isDeposit == 1){
            emit RemoteBalanceUpdated(distributionId, amount, isDeposit);
            distributions[distributionId].totalDeposited += amount;
        }
        
        // withdrawals made on remote vaults
        if(isDeposit == 0) {
            emit RemoteBalanceUpdated(distributionId, amount, isDeposit);
            distributions[distributionId].totalDeposited -= amount;
        }
    }

//------------------------------- LAYERZERO ---------------------------------

    /**
     * @notice Future-proofing, in-case there are LZ changes that result in differing gas usage 
     * @dev Should be left untouched, unless there is an unexpected breaking LZ change
     * @param gasBuffer_ Amount of additional gas for execution on dstChain
     */
    function setGasBuffer(uint128 gasBuffer_) external onlyOwner {
        gasBuffer = gasBuffer_;
    } 

    /** 
     * @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @param to Address of beneficiary
     * @param amount Amount of tokens to be dispensed (expressed in its native precision)
     */
    function quote(bytes32 to, uint256 amount, uint32 dstEid) external view returns (uint256 nativeFee, uint256 lzTokenFee) {
        if(amount == 0) revert Errors.InvalidAmount();
        if(to == bytes32(0)) revert Errors.InvalidAddress();
        
        // payload
        bytes memory payload = abi.encode(to, amount);

        // create options
        bytes memory options;
        options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: GAS_LIMIT + gasBuffer, _value: 0});

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
    function _lzReceive(Origin calldata origin, bytes32 /*guid*/, bytes calldata payload, address /*executor*/, bytes calldata /*options*/) internal virtual override {}


//------------------------------- OWNABLE2STEP ---------------------------------

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