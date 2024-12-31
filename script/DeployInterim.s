// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {StakingPro} from "../src/StakingPro.sol";

contract DeployInterim is Script {
    StakingPro public pool;

    function setUp() public {}

    function run() public {
        console.log("Deploying StakingPro...");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST");
        vm.startBroadcast(deployerPrivateKey);
        
        // constructor params
        address registry = 0x5D4D4b620488DC5CeB13a73a6e700925F7682b02;
        address stakedToken = 0x03946287b52B88C8357E813fbA3F472c60FaE727;
        address storedSigner = address(0);
        
        // Set start time to 24 hours in the future
        uint256 startTime_ = block.timestamp + 24 hours;
        uint256 nftMultiplier = 1000;
        uint256 creationNftsRequired = 1000;
        uint256 vaultCoolDownDuration = 7 days;
        address owner = 0x8C9C001F821c04513616fd7962B2D8c62f925fD2;
        string memory name = "StakingPro";
        string memory version = "1.0.0";

        console.log("Current timestamp:", block.timestamp);
        console.log("Start time:", startTime_);
        console.log("Time difference:", startTime_ - block.timestamp);

        pool = new StakingPro(
            registry,
            stakedToken,
            storedSigner,
            startTime_,
            nftMultiplier,
            creationNftsRequired,
            vaultCoolDownDuration,
            owner,
            name,
            version
        );

        console.log("Deployed StakingPro at:", address(pool));
        vm.stopBroadcast();
    }
}

// forge script script/DeployInterim.s.sol:DeployInterim --rpc-url base_sepolia --broadcast --verify -vvvvv --etherscan-api-key base_sepolia
