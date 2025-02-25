// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT36.t.sol";

abstract contract StateT41_User2StakesToVault2 is StateT36_User2UnstakesFromVault1 {

    function setUp() public override {
        super.setUp();

        // set t41
        vm.warp(41);

        uint256[] memory nftsToStake = new uint256[](2);
        nftsToStake[0] = user2NftsArray[0];
        nftsToStake[1] = user2NftsArray[1];

        //user2 stakes half of his moca + 2 nfts, in vault2
        vm.startPrank(user2);
            pool.stakeTokens(vaultId2, user2Moca/2);
            pool.stakeNfts(vaultId2, nftsToStake); //user2NftsArray[0,1];
        vm.stopPrank();
    }
    
}

/** checking: T36-41
    check vault assets according to stake action at t41
    check vault2 accounts that rewards were received as per unstaked
    check user2 accounts that rewards were received as per unstaked

    - vault1 accounts are stale at t31 - no action taken at t36
    - user1 accounts are stale at t16 - no action taken at t36
 */

contract StateT41_User2StakesToVault2Test is StateT41_User2StakesToVault2 {

    // ---------------- base assets ----------------

    function testPool_T41() public {
        DataTypes.Vault memory vault1 = pool.getVault(vaultId1);
        DataTypes.Vault memory vault2 = pool.getVault(vaultId2);

        // Check total creation NFTs - unchanged
        assertEq(pool.totalCreationNfts(), 6);
        assertEq(pool.totalCreationNfts(), vault1.creationTokenIds.length + vault2.creationTokenIds.length);

        // Check total staked assets
        assertEq(pool.totalStakedNfts(), 4);                         // user2 staked 2 nfts to vault2
        assertEq(pool.totalStakedTokens(), user1Moca + user2Moca);   // user2 staked half of tokens to vault2
        assertEq(pool.totalStakedRealmPoints(), user1Rp + user2Rp);  // unchanged: migrateRp
        
        // check boosted assets
        
            // both vaults enjoy boosting
            uint256 expectedBoostFactor = 10_000 + (vault1.stakedNfts * pool.NFT_MULTIPLIER());
            
            // check boosted rp
            uint256 expectedUnboostedRp = user2Rp/2; // vault2 has no boost
            uint256 expectedBoostedRp = ((user1Rp + user2Rp/2) * expectedBoostFactor) / 10_000; // vault1 boost
            uint256 expectedTotalBoostedRp = expectedUnboostedRp + expectedBoostedRp;
            uint256 expectedBoostedTokens = ((user1Moca + user2Moca/2) * expectedBoostFactor) / 10_000; // vault1 boost

        assertEq(pool.totalBoostedRealmPoints(), expectedTotalBoostedRp);       
        assertEq(pool.totalBoostedStakedTokens(), expectedBoostedTokens);    
    }
    
    // user2 unstaked half of tokens + 2 nfts 
    function testVault1_T36() public {
        DataTypes.Vault memory vault1 = pool.getVault(vaultId1);
        
        // Check base balances
        assertEq(vault1.stakedRealmPoints, user1Rp + user2Rp/2);
        assertEq(vault1.stakedTokens, user1Moca + user2Moca/2);
        assertEq(vault1.stakedNfts, 2);

        // Check boosted values
        uint256 boostFactor = 10_000 + (vault1.stakedNfts * pool.NFT_MULTIPLIER());
        uint256 expectedBoostedRp = (vault1.stakedRealmPoints * boostFactor) / 10_000;
        uint256 expectedBoostedTokens = (vault1.stakedTokens * boostFactor) / 10_000;
        
        assertEq(vault1.totalBoostFactor, boostFactor);
        assertEq(vault1.boostedRealmPoints, expectedBoostedRp);
        assertEq(vault1.boostedStakedTokens, expectedBoostedTokens);
    }

    // vault2 should be stale as per T31
    function testVault2_T36() public {
        DataTypes.Vault memory vault2 = pool.getVault(vaultId2);
        
        // Check base balances
        assertEq(vault2.stakedRealmPoints, user2Rp/2);
        assertEq(vault2.stakedTokens, 0);
        assertEq(vault2.stakedNfts, 0);

        // Check boosted values
        uint256 boostFactor = 10_000 + (vault2.stakedNfts * pool.NFT_MULTIPLIER());
        uint256 expectedBoostedRp = (vault2.stakedRealmPoints * boostFactor) / 10_000;
        uint256 expectedBoostedTokens = (vault2.stakedTokens * boostFactor) / 10_000;

        assertEq(vault2.totalBoostFactor, boostFactor);
        assertEq(vault2.boostedRealmPoints, expectedBoostedRp);
        assertEq(vault2.boostedStakedTokens, expectedBoostedTokens);
    }

}
