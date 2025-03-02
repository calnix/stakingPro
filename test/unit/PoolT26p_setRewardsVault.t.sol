// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT21.t.sol";

//note: creation nfts updated at t21 | distribution_1 starts at t21
abstract contract StateT26p_SetRewardsVault is StateT21_CreationNftsUpdated {

    function setUp() public virtual override {
        super.setUp();
        
        vm.warp(26);

    }
}