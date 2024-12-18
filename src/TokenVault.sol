// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";


// this is just a container. all calcs and tracking is on staking contract
contract TokenVault is AccessControl {
    using SafeERC20 for IERC20;

    address public pool;

    // roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MONEY_MANAGER_ROLE = keccak256("MONEY_MANAGER_ROLE");
    
    struct Distribution {
        uint256 chainId;
        bytes32 tokenAddress;
        
        uint256 totalClaimed;
        uint256 totalDeposited;
    }

    mapping(uint256 distributionId => Distribution distribution) public distributions;

    // events
    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    event RecoveredTokens(address indexed token, address indexed target, uint256 indexed amount);
    event PoolSet(address indexed oldPool, address indexed newPool);

    // errors
    error IncorrectToken();
    error InsufficientDeposits();

    constructor(address moneyManager, address admin) {

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

    /**
     * @notice Called by Staking Pool contract to transfer rewards to users
     * @param to Address to which rewards are to be paid out
     * @param amount Reward amount (expressed in the token's precision)
     */
    function payRewards(uint256 distributionId, address to, uint256 amount) external {
        require(msg.sender == pool, "Only Pool");

        Distribution memory distribution = distributions[distributionId];
        
        // check balance
        uint256 available = distribution.totalDeposited - distribution.totalClaimed;
        if(available < amount) revert InsufficientDeposits();

        // update
        distribution.totalClaimed += amount;

        // get address
        address token = bytes32ToAddress(distribution.tokenAddress);
        
        // update storage
        distributions[distributionId] = distribution;

        IERC20(token).safeTransfer(to, amount);
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

} 
    



/**
    Setup a distribution
    - deposit required into here
    - setUpDistribution on pool
    
    - should setUpDistri on pool sanity check tokenVault?
    - yes, cos we can have multiple distributions, for the same token.


 */