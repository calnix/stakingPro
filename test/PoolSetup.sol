// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2, stdStorage, StdStorage} from "forge-std/Test.sol";

import "../src/StakingPro.sol";
import "../src/RewardsVaultV1.sol";

// mocks
import "../test/mocks/MocaToken.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {NftRegistry} from "../lib/NftLocker/src/NftRegistry.sol";


abstract contract PoolSetup is Test {
    using stdStorage for StdStorage;

    // contracts
    StakingPro public pool;
    RewardsVaultV1 public rewardsVault;

    // staking assets
    MocaToken public mocaToken;  
    NftRegistry public nftRegistry;   
    
    // rewards
    ERC20Mock public mockToken1;
    ERC20Mock public mockToken2;
    ERC20Mock public mockToken3;

    // entities
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public owner = makeAddr("owner");
    address public monitor = makeAddr("monitor");   
    address public operator = makeAddr("operator");
    address public depositor = makeAddr("depositor");

    // user assets
    uint256 public user1Moca;
    uint256 public user2Moca;
    uint256 public user3Moca;

    uint256 public user1Nfts;
    uint256 public user2Nfts;
    uint256 public user3Nfts;

    // stakingPool constructor data
    uint256 public startTime = block.timestamp;
    uint256 public nftMultiplier = 1000;
    uint256 public creationNftsRequired = 5;
    uint256 public vaultCoolDownDuration = 1 days;
    
    function setUp() public virtual {
        // starting point: T0
        vm.warp(0 days); 

        // entities
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        monitor = makeAddr("monitor");
        operator = makeAddr("operator");
        depositor = makeAddr("depositor");

        // address endpoint, address owner, address pool, uint32 dstEid
        nftRegistry = new NftRegistry(address(0), owner, address(pool), 0);

        // mocaToken
        mocaToken = new MocaToken("MocaToken", "MOCA");   

        pool = new StakingPro(
            address(nftRegistry),
            address(mocaToken), 
            startTime,
            nftMultiplier,
            creationNftsRequired,
            vaultCoolDownDuration,
            owner,
            monitor,
            "StakingPro",
            "1");

        // address moneyManager, address monitor, address owner, address pool
        rewardsVault = new RewardsVaultV1(owner, owner, owner, address(pool));



    }
}
