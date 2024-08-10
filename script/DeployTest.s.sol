// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {StakingPro} from "./../src/StakingPro.sol";


contract DeployTest is Script {
    StakingPro public pool;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST");
        vm.startBroadcast(deployerPrivateKey);

        //pool = new StakingPro();

        vm.stopBroadcast();
    }
}

// forge script script/DeployTest.s.sol:DeployTest --rpc-url sepolia --broadcast --verify -vvvvv --etherscan-api-key sepolia --legacy
