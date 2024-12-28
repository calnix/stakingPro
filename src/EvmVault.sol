// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
//import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

contract EVMVault is OApp, Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    // the eid of the destination chain
    uint32 public immutable dstEid;

    // Track token balances and activity
    struct TokenInfo {
        uint256 totalDeposited;     // Total amount deposited
        uint256 totalWithdrawn;     // Total amount withdrawn
        uint256 totalPaidOut;       // Total amount paid out as rewards
    }

    // Token address => TokenInfo
    mapping(address token => TokenInfo tokenInfo) public tokens;

    // Track rewards paid out to each user for each token
    mapping(address user => mapping(address token => uint256 amount)) public users;

    //errors
    error InvalidToken();
    error ExcessDeposit();
    error InsufficientBalance();
    error InsufficientGas();

    // events
    event Deposit(address token, address from, uint256 amount, uint256 distributionId);
    event Withdraw(address token, address to, uint256 amount, uint256 distributionId);
    event PayRewards(address token, address to, uint256 amount);
    event SetUpToken(address token);

    constructor(uint32 dstEid_, address endpoint, address owner) OApp(endpoint, owner) Ownable(owner) {
        dstEid = dstEid_;
    }

    //------------------------------- DEPOSIT/WITHDRAW ---------------------------------

    //note: call back to home: rewards vault
    //note: caller is expected to reference the Distribution.totalRequired on the RewardsVault
    function deposit(address token, uint256 amount, address from, uint256 distributionId) external payable onlyOwner {
        if(token == address(0)) revert InvalidToken();
        
        // update distribution
        tokens[token].totalDeposited += amount;

        emit Deposit(token, from, amount, distributionId);
        
        //----------------------- LZ stuff -----------------------

            // create options
            bytes memory options;
            //options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

            // craft payload: isDeposit = 1
            bytes memory payload = abi.encode(distributionId, amount, 1);

            // check gas needed
            MessagingFee memory fee = _quote(dstEid, payload, options, false);
            if(msg.value < fee.nativeFee) revert InsufficientGas();
            
            // MessagingFee: Fee struct containing native gas and ZRO token
            // returns MessagingReceipt struct
            _lzSend(dstEid, payload, options, fee, payable(msg.sender));

        //----------------------- ----- -----------------------

    }
    
    //note: call back to home: rewards vault
    function withdraw(address token, uint256 amount, address to, uint256 distributionId) external payable onlyOwner {
        if(token == address(0)) revert InvalidToken();

        TokenInfo memory tokenInfo = tokens[token];
        
        // check balance
        if(tokenInfo.totalWithdrawn + amount > tokenInfo.totalDeposited) revert InsufficientBalance();
        // update
        tokenInfo.totalWithdrawn += amount;
        
        // storage
        tokens[token] = tokenInfo;

        emit Withdraw(token, to, amount, distributionId);  

        //----------------------- LZ stuff -----------------------

            // create options
            bytes memory options;
            //options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

            // craft payload: isDeposit = 0
            bytes memory payload = abi.encode(distributionId, amount, 0);


            // check gas needed
            MessagingFee memory fee = _quote(dstEid, payload, options, false);
            if(msg.value < fee.nativeFee) revert InsufficientGas();
            
            // MessagingFee: Fee struct containing native gas and ZRO token
            // returns MessagingReceipt struct
            _lzSend(dstEid, payload, options, fee, payable(msg.sender));

        //----------------------- ----- -----------------------
    }

    //------------------------------- PAY REWARDS ---------------------------------
    function payRewards(address token, address receiver, uint256 amount) external payable onlyOwner virtual {
        
        tokens[token].totalPaidOut += amount;
        
        // transfer to user
        IERC20(token).safeTransfer(receiver, amount);

        emit PayRewards(token, receiver, amount);
    }


//------------------------------- LAYERZERO ---------------------------------

    /*//////////////////////////////////////////////////////////////
                               LAYERZERO
    //////////////////////////////////////////////////////////////*/

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

        // transfer to user
        IERC20(token).safeTransfer(receiver, amount);

        emit PayRewards(token, receiver, amount);
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
