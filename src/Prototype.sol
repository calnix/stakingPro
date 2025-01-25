// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library PoolLogic {

    function executeStake() external returns (uint256) {
        return 1;
    }
}

contract Pool {
 
    uint256 public state;

    function stake() external {

        state = PoolLogic.executeStake();
    } 
}