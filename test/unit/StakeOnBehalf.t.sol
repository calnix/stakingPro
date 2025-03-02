// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT36.t.sol";

/**
    Split timeline:
    -T26: user2 creates vault2
    -T31: user2 migrates half his RP to vault2
    -T36: user2 unstakes moca and 2 nfts from vault1
    -T41: user 2 stakes moca and 2 nfts in vault2

    we will create a parallel timeline on T41,
    - user2 unstakes from tokens from vault1; but does not restake tokens
    - instead OPERATOR stakes the same amount of tokens on behalf of user2
    - from a rewards perspective, user2 should be credited with the same rewards as main timeline

    we will check that:
    - pool state is updated correctly
    - vault assets are updated correctly
    - vault2 accounts are updated correctly
    - user2's vault2 accounts are updated correctly
    - after a timedelta of 5s, check that rewards are accrued correctly
 */

abstract contract StateT41_User2StakesToVault2_OperatorStakesOnBehalf is StateT36_User2UnstakesFromVault1 {

    function setUp() public virtual override {
        super.setUp();

        vm.warp(41);
        
        uint256[] memory nftsToStake = new uint256[](2);
        nftsToStake[0] = user2NftsArray[0];
        nftsToStake[1] = user2NftsArray[1];

        //user2 stakes half of his moca + 2 nfts, in vault2
        vm.startPrank(user2);
            pool.stakeNfts(vaultId2, nftsToStake); 
        vm.stopPrank();

        // operator stakes on behalf of user2
        vm.startPrank(operator);
            
            bytes32[] memory vaultIds = new bytes32[](1);
            vaultIds[0] = vaultId2;
            
            address[] memory onBehalfOfs = new address[](1);
            onBehalfOfs[0] = user2;
            
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = user2Moca/2;

            mocaToken.approve(address(pool), user2Moca/2);
            pool.stakeOnBehalfOf(vaultIds, onBehalfOfs, amounts);
        vm.stopPrank();
    }
}
