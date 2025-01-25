// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {StakingPro} from "../src/StakingPro.sol";

import {RewardsVaultV1} from "../src/RewardsVaultV1.sol";

// mocks
import {ERC20Mock} from "./../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract DeployInterim is Script {
    StakingPro public pool;
    RewardsVaultV1 public rewardsVault;

    ERC20Mock public mockToken;

    function setUp() public {}

    function addressToBytes32(address addr) public pure returns(bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 bytes32_) public pure returns(address) {
        return address(uint160(uint256(bytes32_)));
    }

    function run() public {
        console.log("Deploying StakingPro...");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST");
        vm.startBroadcast(deployerPrivateKey);
        
        // constructor params
        address registry = 0x5D4D4b620488DC5CeB13a73a6e700925F7682b02;
        address stakedToken = 0x03946287b52B88C8357E813fbA3F472c60FaE727;
        
        // Set start time to 24 hours in the future
        uint256 startTime_ = block.timestamp + 10;
        uint256 nftMultiplier = 1000; // 10% boost
        uint256 creationNftsRequired = 5;
        uint256 vaultCoolDownDuration = 7 days;
        address owner = 0x8C9C001F821c04513616fd7962B2D8c62f925fD2;

        console.log("Current timestamp:", block.timestamp);
        console.log("Start time:", startTime_);
        console.log("Time difference:", startTime_ - block.timestamp);

        pool = new StakingPro(
            registry,
            stakedToken, 
            startTime_,
            nftMultiplier,
            creationNftsRequired,
            vaultCoolDownDuration,
            owner,
            owner,
            "StakingPro",
            "1"
        );

        rewardsVault = new RewardsVaultV1(
            owner,
            owner,
            owner,
            address(pool)
        );

        // connect pool and rewardsVault
        pool.setRewardsVault(address(rewardsVault));

        // setup distribution
        pool.setupDistribution(
            0,
            startTime_,
            0,
            1e18,
            1E18,
            0,
            bytes32(0)
        );

        console.log("Deployed StakingPro at:", address(pool));
        console.log("Deployed RewardsVault at:", address(rewardsVault));

        // distribution 1
        uint256 duration = 90 days;
        uint256 startTime = block.timestamp + 100;
        uint256 endTime = startTime + duration;

        uint256 totalRewards = 90 ether;
        uint256 emissionPerSecond = 1 ether; // 90 / 90 days = 1 ether per day

        // mock token
        mockToken = new ERC20Mock();
        mockToken.mint(owner, totalRewards);
        mockToken.approve(address(rewardsVault), totalRewards);


        pool.setupDistribution(
            1,
            startTime,
            endTime,
            emissionPerSecond,
            1E18,
            30184,              // BASE EID
            bytes32(uint256(uint160(address(mockToken))))
        );

        // deposit rewards
        rewardsVault.deposit(1, totalRewards, owner);

        vm.stopBroadcast();
    }
}

// forge script script/DeployInterim.s.sol:DeployInterim --rpc-url base_sepolia --broadcast --verify -vvvvv --etherscan-api-key base_sepolia

// do ya wanna create2? https://book.getfoundry.sh/tutorials/create2-tutorial?highlight=create2#create2-factory