// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT61.t.sol";

contract StateT61And1Day_Vault2Ended is StateT61_Vault2CooldownActivated {

    // for reference
    DataTypes.Vault vault1_T61And1Day; 
    DataTypes.Vault vault2_T61And1Day;

    DataTypes.Distribution distribution0_T61And1Day;
    DataTypes.Distribution distribution1_T61And1Day;
    //vault1
    DataTypes.VaultAccount vault1Account0_T61And1Day;
    DataTypes.VaultAccount vault1Account1_T61And1Day;
    //vault2
    DataTypes.VaultAccount vault2Account0_T61And1Day;
    DataTypes.VaultAccount vault2Account1_T61And1Day;
    //user1+vault1
    DataTypes.UserAccount user1Vault1Account0_T61And1Day;
    DataTypes.UserAccount user1Vault1Account1_T61And1Day;
    //user2+vault1
    DataTypes.UserAccount user2Vault1Account0_T61And1Day;
    DataTypes.UserAccount user2Vault1Account1_T61And1Day;
    //user1+vault2
    DataTypes.UserAccount user1Vault2Account0_T61And1Day;
    DataTypes.UserAccount user1Vault2Account1_T61And1Day;
    //user2+vault2
    DataTypes.UserAccount user2Vault2Account0_T61And1Day;
    DataTypes.UserAccount user2Vault2Account1_T61And1Day;

    function setUp() public virtual override {
        super.setUp();

        vm.warp(61 + 1 days);

        // end vault2
        bytes32[] memory vaultIds = new bytes32[](1);
        vaultIds[0] = vaultId2;

        pool.endVaults(vaultIds);
    
        // save state
        vault1_T61And1Day = pool.getVault(vaultId1);
        vault2_T61And1Day = pool.getVault(vaultId2);
        
        distribution0_T61And1Day = getDistribution(0); 
        distribution1_T61And1Day = getDistribution(1);

        vault1Account0_T61And1Day = getVaultAccount(vaultId1, 0);
        vault1Account1_T61And1Day = getVaultAccount(vaultId1, 1);  
        vault2Account0_T61And1Day = getVaultAccount(vaultId2, 0);
        vault2Account1_T61And1Day = getVaultAccount(vaultId2, 1);

        user1Vault1Account0_T61And1Day = getUserAccount(user1, vaultId1, 0);
        user1Vault1Account1_T61And1Day = getUserAccount(user1, vaultId1, 1);
        user2Vault1Account0_T61And1Day = getUserAccount(user2, vaultId1, 0);
        user2Vault1Account1_T61And1Day = getUserAccount(user2, vaultId1, 1);
        user1Vault2Account0_T61And1Day = getUserAccount(user1, vaultId2, 0);
        user1Vault2Account1_T61And1Day = getUserAccount(user1, vaultId2, 1);
        user2Vault2Account0_T61And1Day = getUserAccount(user2, vaultId2, 0);
        user2Vault2Account1_T61And1Day = getUserAccount(user2, vaultId2, 1);
    }
}

contract StateT61And1Day_Vault2EndedTest is StateT61And1Day_Vault2Ended {

    function testPool_T61And1Day() public {
        DataTypes.Vault memory vault1 = pool.getVault(vaultId1);
        DataTypes.Vault memory vault2 = pool.getVault(vaultId2);

        // Check total creation NFTs - unchanged
        assertEq(pool.totalCreationNfts(), 5);        // only vault1 left
        assertEq(pool.totalCreationNfts(), vault1.creationTokenIds.length);

        // Check total staked assets: vault2 assets are gone
        assertEq(pool.totalStakedNfts(), 2);                         // vault1 has 2 staked
        assertEq(pool.totalStakedTokens(), user1Moca + user2Moca/2);   
        assertEq(pool.totalStakedRealmPoints(), user1Rp + user2Rp/2);  
        // x-ref pool against vault1
        assertEq(pool.totalStakedNfts(), vault1_T61And1Day.stakedNfts);                       
        assertEq(pool.totalStakedTokens(), vault1_T61And1Day.stakedTokens);   
        assertEq(pool.totalStakedRealmPoints(), vault1_T61And1Day.stakedRealmPoints);
        assertEq(pool.totalBoostedStakedTokens(), vault1_T61And1Day.boostedStakedTokens);   
        assertEq(pool.totalBoostedRealmPoints(), vault1_T61And1Day.boostedRealmPoints);
        
        // check boosted assets: vault1 enjoys boosting
        
            // calculate boost factors for both vaults
            uint256 vault1BoostFactor = 10_000 + (vault1.stakedNfts * pool.NFT_MULTIPLIER());
            
            // calculate boosted rp for each vault
            uint256 vault1BoostedRp = ((user1Rp + user2Rp/2) * vault1BoostFactor) / 10_000; // vault1 boost
            uint256 expectedTotalBoostedRp = vault1BoostedRp;

            // calculate boosted tokens for each vault
            uint256 vault1BoostedTokens = ((user1Moca + user2Moca/2) * vault1BoostFactor) / 10_000;
            uint256 expectedTotalBoostedTokens = vault1BoostedTokens;

        assertEq(pool.totalBoostedRealmPoints(), expectedTotalBoostedRp);       
        assertEq(pool.totalBoostedStakedTokens(), expectedTotalBoostedTokens);
    }

    function testVault1_T61And1Day() public {
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

        // Check fee factors
        assertEq(vault1.nftFeeFactor, 1500);          
        assertEq(vault1.creatorFeeFactor, 0);         
        assertEq(vault1.realmPointsFeeFactor, 1500);  
    }   

    // vault2 assets are removed from the system, but still exist in the vault
    function testVault2_T61And1Day() public {
        DataTypes.Vault memory vault2 = pool.getVault(vaultId2);
        
        // Check base balances
        assertEq(vault2.stakedRealmPoints, user2Rp/2);
        assertEq(vault2.stakedTokens, user2Moca/2);
        assertEq(vault2.stakedNfts, 2);

        // Check boosted values
        uint256 boostFactor = 10_000 + (vault2.stakedNfts * pool.NFT_MULTIPLIER());
        uint256 expectedBoostedRp = (vault2.stakedRealmPoints * boostFactor) / 10_000;
        uint256 expectedBoostedTokens = (vault2.stakedTokens * boostFactor) / 10_000;

        assertEq(vault2.totalBoostFactor, boostFactor);
        assertEq(vault2.boostedRealmPoints, expectedBoostedRp);
        assertEq(vault2.boostedStakedTokens, expectedBoostedTokens);

        // Check fee factors
        assertEq(vault2.nftFeeFactor, 1250);          
        assertEq(vault2.creatorFeeFactor, 0);       
        assertEq(vault2.realmPointsFeeFactor, 750);  
    }    

    // ---------------- distribution 0 ----------------

}
