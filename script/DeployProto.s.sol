// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Pool} from "../src/Prototype.sol";

contract DeployProto is Script {
    function run() external returns (Pool) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST");
        vm.startBroadcast(deployerPrivateKey);

        Pool pool = new Pool();

        console.log("Deployed at:", address(pool));
        vm.stopBroadcast();
    }
}

// forge script script/DeployProto.s.sol:DeployProto --rpc-url base_sepolia --broadcast --verify -vvvvv --etherscan-api-key base_sepolia


contract CallPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST");
        vm.startBroadcast(deployerPrivateKey);

        Pool pool = Pool(0xBf7b07A57222c9443d2deFBb0452Bb9B67d7Ce9E); // Replace with actual deployed address
        pool.stake();

        console.log("Called stake() on Pool at:", address(pool));
        vm.stopBroadcast();
    }
}

// forge script script/DeployProto.s.sol:CallPool --rpc-url base_sepolia --broadcast -vvvvv
