// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./Events.sol";
import "./Errors.sol";

// OZ
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { SafeERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

// LZ
import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

contract EVMVault is OApp, Pausable, Ownable2Step, AccessControl {
    using SafeERC20 for IERC20;

    // the eid of the destination chain
    uint32 public immutable dstEid;
    
    // roles
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");                // only pause  
    bytes32 public constant MONEY_MANAGER_ROLE = keccak256("MONEY_MANAGER_ROLE");    // withdraw/deposit

    // Track token balances and activity
    struct TokenInfo {
        uint256 totalDeposited;     // Total amount deposited
        uint256 totalPaidOut;       // Total amount paid out as rewards
        uint256 totalUnclaimable;   // Total amount unclaimable due to insufficient balance
    }

    // Token address => TokenInfo
    mapping(address token => TokenInfo tokenInfo) public tokens;
    // Track rewards paid out to each user for each token
    mapping(address user => mapping(address token => uint256 amount)) public paidOut;
    // Track rewards unclaimable due to insufficient balance
    mapping(address user => mapping(address token => uint256 amount)) public unclaimable;
    
    constructor(uint32 dstEid_, address endpoint, address owner, address monitor, address moneyManager) OApp(endpoint, owner) Ownable(owner) {
        dstEid = dstEid_;

        // access control
        _grantRole(DEFAULT_ADMIN_ROLE, owner);              // default admin role for all roles
        
        _grantRole(MONITOR_ROLE, monitor);                  // risk monitoring script
        _grantRole(MONEY_MANAGER_ROLE, moneyManager);
    }

    /**
     * @notice Allows users to collect previously unclaimable rewards for a specific token
     * @dev This function enables users to claim rewards that were previously unclaimable due to insufficient vault balance
     * @param token The address of the token to collect unclaimable rewards for
     */
    function collectUnclaimedRewards(address token) external {
        if(token == address(0)) revert Errors.InvalidTokenAddress();

        uint256 unclaimableAmount = unclaimable[msg.sender][token];
        if(unclaimableAmount == 0) revert Errors.NoUnclaimedRewards();
        
        // token info
        TokenInfo storage tokenInfo = tokens[token];

        uint256 available = tokenInfo.totalDeposited - tokenInfo.totalPaidOut;
        uint256 amountToPay = available < unclaimableAmount ? available : unclaimableAmount;

        // update storage
        tokenInfo.totalPaidOut += amountToPay;
        tokenInfo.totalUnclaimable -= amountToPay;
        unclaimable[msg.sender][token] -= amountToPay;

        emit CollectUnclaimedRewards(token, msg.sender, amountToPay);

        // transfer what we can pay
        IERC20(token).safeTransfer(msg.sender, amountToPay);
    }

//------------------------------- DEPOSIT/WITHDRAW ---------------------------------

    //note: call back to home: rewards vault
    //note: caller is expected to reference Distribution.totalRequired on the RewardsVault
    /**
     * @notice Deposits tokens into the vault and notifies the rewards vault on the home chain
     * @dev Only callable by owner. Requires sufficient gas to cover LayerZero messaging fees.
     * @param token The address of the token being deposited
     * @param amount The amount of tokens to deposit
     * @param from The address the tokens are being deposited from
     * @param distributionId The ID of the distribution these tokens are for
     */
    function deposit(address token, uint256 amount, address from, uint256 distributionId) external payable onlyRole(MONEY_MANAGER_ROLE) {
        if(token == address(0)) revert Errors.InvalidTokenAddress();
        if(distributionId == 0) revert Errors.InvalidDistributionId();
        
        // update distribution
        tokens[token].totalDeposited += amount;

        emit Deposit(token, from, amount, distributionId);
        
        //----------------------- LZ stuff -----------------------
        /*
            // create options
            bytes memory options;
            options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

            // craft payload: isDeposit = 1
            bytes memory payload = abi.encode(distributionId, amount, 1);

            // check gas needed
            MessagingFee memory fee = _quote(dstEid, payload, options, false);
            if(msg.value < fee.nativeFee) revert Errors.InsufficientGas();
            
            // MessagingFee: Fee struct containing native gas and ZRO token
            // returns MessagingReceipt struct
            //_lzSend(dstEid, payload, options, fee, payable(msg.sender));
        */

        //----------------------- ----- -----------------------
    }
    
    /** 
     * @notice Withdraws tokens from the vault
     * @dev Calls back to the rewards vault on the home chain, to update the distribution
     * @param token The address of the token being withdrawn
     * @param amount The amount of tokens to withdraw
     * @param to The address the tokens are being withdrawn to
     * @param distributionId The ID of the distribution these tokens are for
     */
    function withdraw(address token, uint256 amount, address to, uint256 distributionId) external payable onlyRole(MONEY_MANAGER_ROLE) {
        if(token == address(0)) revert Errors.InvalidTokenAddress();

        TokenInfo memory tokenInfo = tokens[token];
        
        // check balance
        if(tokenInfo.totalDeposited < amount) revert Errors.InsufficientBalance();

        // update
        tokenInfo.totalDeposited -= amount;
        
        // storage
        tokens[token] = tokenInfo;

        emit Withdraw(token, to, amount, distributionId);  

        //----------------------- LZ stuff -----------------------
            /*
            // create options
            bytes memory options;
            //options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

            // craft payload: isDeposit = 0
            bytes memory payload = abi.encode(distributionId, amount, 0);


            // check gas needed
            MessagingFee memory fee = _quote(dstEid, payload, options, false);
            if(msg.value < fee.nativeFee) revert Errors.InsufficientGas();
            
            // MessagingFee: Fee struct containing native gas and ZRO token
            // returns MessagingReceipt struct
            _lzSend(dstEid, payload, options, fee, payable(msg.sender));
            */

        //----------------------- ----- -----------------------
    }

//------------------------------- LAYERZERO ---------------------------------

    function quote(uint256 distributionId, uint256 amount, bool isDeposit) external view returns (uint256 nativeFee, uint256 lzTokenFee) {

        bytes memory payload = abi.encode(distributionId, amount, isDeposit);
        
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
    function _lzReceive(Origin calldata /*origin*/, bytes32 /*guid*/, bytes calldata payload, address /*executor*/, bytes calldata /*options*/) internal override {

        (bytes32 tokenAddress, uint256 amount, address receiver) = abi.decode(payload, (bytes32, uint256, address));
        
        // convert bytes32 to address
        address token = address(uint160(uint256(tokenAddress)));

        TokenInfo memory tokenInfo = tokens[token];
        uint256 available = tokenInfo.totalDeposited - tokenInfo.totalPaidOut;

        // If available balance is less than requested amount, store difference as unclaimable
        if (available < amount) {

            uint256 unclaimableAmount = amount - available;

            unclaimable[receiver][token] += unclaimableAmount;
            tokens[token].totalUnclaimable += unclaimableAmount;

            emit UnclaimedRewards(token, receiver, unclaimableAmount);

            // Transfer whatever is available
            if(available > 0) {
                emit PayRewards(token, receiver, available);
                IERC20(token).safeTransfer(receiver, available);
            }
            
        } else {

            // Full amount available, transfer it all            
            emit PayRewards(token, receiver, amount);
            IERC20(token).safeTransfer(receiver, amount);
        }
    }

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
}