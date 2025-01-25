// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2, stdStorage, StdStorage} from "forge-std/Test.sol";

import "../src/StakingPro.sol";
import "../src/RewardsVaultV1.sol";

abstract contract PoolSetup is Test {
    using stdStorage for StdStorage;

    StakingPro public pool;
    RewardsVaultV1 public rewardsVault;

    function setUp() public {
        pool = new StakingPro();
        rewardsVault = new RewardsVaultV1();
    }
}
