// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT41.t.sol";

abstract contract StateT46BothUsersUpdateVaultsFees is StateT41_User2StakesToVault2 {

    // for reference
    DataTypes.Vault vault1_T46; 
    DataTypes.Vault vault2_T46;

    DataTypes.Distribution distribution0_T46;
    DataTypes.Distribution distribution1_T46;
    //vault1
    DataTypes.VaultAccount vault1Account0_T46;
    DataTypes.VaultAccount vault1Account1_T46;
    //vault2
    DataTypes.VaultAccount vault2Account0_T46;
    DataTypes.VaultAccount vault2Account1_T46;
    //user1+vault1
    DataTypes.UserAccount user1Account0_T46;
    DataTypes.UserAccount user1Account1_T46;
    //user2+vault1
    DataTypes.UserAccount user2Account0_T46;
    DataTypes.UserAccount user2Account1_T46;
    //user1+vault2
    DataTypes.UserAccount user1Vault2Account0_T46;
    DataTypes.UserAccount user1Vault2Account1_T46;
    //user2+vault2
    DataTypes.UserAccount user2Vault2Account0_T46;
    DataTypes.UserAccount user2Vault2Account1_T46;

    function setUp() public virtual override {
        super.setUp();

        vm.warp(46);

        // Vault1 fees - user1 reduces creator fee, increases nft and rp fees
        uint256 creatorFeeFactor1 = 500; // Reduced from 1000
        uint256 nftFeeFactor1 = 1250;
        uint256 realmPointsFeeFactor1 = 1250;

        vm.startPrank(user1);
            pool.updateVaultFees(vaultId1, nftFeeFactor1, creatorFeeFactor1, realmPointsFeeFactor1);
        vm.stopPrank();

        // Vault2 fees - user2 reduces creator fee, increases nft and rp fees
        uint256 creatorFeeFactor2 = 250; // Reduced from 500
        uint256 nftFeeFactor2 = 1125;
        uint256 realmPointsFeeFactor2 = 625;

        vm.startPrank(user2);
            pool.updateVaultFees(vaultId2, nftFeeFactor2, creatorFeeFactor2, realmPointsFeeFactor2);
        vm.stopPrank();

        // save state
        vault1_T46 = pool.getVault(vaultId1);
        vault2_T46 = pool.getVault(vaultId2);
        
        distribution0_T46 = getDistribution(0); 
        distribution1_T46 = getDistribution(1);
        vault1Account0_T46 = getVaultAccount(vaultId1, 0);
        vault1Account1_T46 = getVaultAccount(vaultId1, 1);  
        vault2Account0_T46 = getVaultAccount(vaultId2, 0);
        vault2Account1_T46 = getVaultAccount(vaultId2, 1);
        user1Account0_T46 = getUserAccount(user1, vaultId1, 0);
        user1Account1_T46 = getUserAccount(user1, vaultId1, 1);
        user2Account0_T46 = getUserAccount(user2, vaultId1, 0);
        user2Account1_T46 = getUserAccount(user2, vaultId1, 1);
        user1Vault2Account0_T46 = getUserAccount(user1, vaultId2, 0);
        user1Vault2Account1_T46 = getUserAccount(user1, vaultId2, 1);
        user2Vault2Account0_T46 = getUserAccount(user2, vaultId2, 0);
        user2Vault2Account1_T46 = getUserAccount(user2, vaultId2, 1);
    }

}

/** check assets: T46
    assets remain unchanged from T41
    
    check accounts: T41-46
     vault1: rp: user1Rp + user2Rp/2 | tokens: user1Moca + user2Moca/2 | nfts: 2
     vault2: rp: user1Rp + user2Rp/2 | tokens: user1Moca + user2Moca/2 | nfts: 2

    check all user and vault accounts.
 */

contract StateT46BothUsersUpdateVaultsFeesTest is StateT46BothUsersUpdateVaultsFees {

    // ---------------- base assets ----------------

    function testPool_T46() public {
        DataTypes.Vault memory vault1 = pool.getVault(vaultId1);
        DataTypes.Vault memory vault2 = pool.getVault(vaultId2);

        // Check total creation NFTs - unchanged
        assertEq(pool.totalCreationNfts(), 6);
        assertEq(pool.totalCreationNfts(), vault1.creationTokenIds.length + vault2.creationTokenIds.length);

        // Check total staked assets: both users have committed in full
        assertEq(pool.totalStakedNfts(), 4);                         
        assertEq(pool.totalStakedTokens(), user1Moca + user2Moca);   
        assertEq(pool.totalStakedRealmPoints(), user1Rp + user2Rp);  
        
        // check boosted assets: both vaults enjoy boosting
        
            // calculate boost factors for both vaults
            uint256 vault1BoostFactor = 10_000 + (vault1.stakedNfts * pool.NFT_MULTIPLIER());
            uint256 vault2BoostFactor = 10_000 + (vault2.stakedNfts * pool.NFT_MULTIPLIER());
            
            // calculate boosted rp for each vault
            uint256 vault1BoostedRp = ((user1Rp + user2Rp/2) * vault1BoostFactor) / 10_000; // vault1 boost
            uint256 vault2BoostedRp = ((user2Rp/2) * vault2BoostFactor) / 10_000; // vault2 boost
            uint256 expectedTotalBoostedRp = vault1BoostedRp + vault2BoostedRp;

            // calculate boosted tokens for each vault
            uint256 vault1BoostedTokens = ((user1Moca + user2Moca/2) * vault1BoostFactor) / 10_000;
            uint256 vault2BoostedTokens = ((user2Moca/2) * vault2BoostFactor) / 10_000;
            uint256 expectedTotalBoostedTokens = vault1BoostedTokens + vault2BoostedTokens;

        assertEq(pool.totalBoostedRealmPoints(), expectedTotalBoostedRp);       
        assertEq(pool.totalBoostedStakedTokens(), expectedTotalBoostedTokens);    
    }

    function testVault1_T46() public {
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

    function testVault2_T46() public {
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
    }

    // ---------------- distribution 0 ----------------

    function testDistribution0_T46() public {

        DataTypes.Distribution memory distribution = getDistribution(0);

        // static
        assertEq(distribution.distributionId, 0);
        assertEq(distribution.TOKEN_PRECISION, 1e18); 
        assertEq(distribution.endTime, 0);
        assertEq(distribution.startTime, 1);
        assertEq(distribution.emissionPerSecond, 1 ether);
        assertEq(distribution.manuallyEnded, 0);        
        
        /** TODO
            index calc: t41 - t46   [delta: 5]
            - prev. index: 4.382e16 [t41: 43826723671924909]
            - totalEmittedSinceLastUpdate: 5e18 SP
            - vault1: (user1Rp + user2Rp/2) * 1.2 [boosted by 2 NFTs] = 1000 * 1.2 = 1200
            - vault2: (user2Rp/2) * 1.2 [boosted by 2 NFTs] = 500 * 1.2 = 600
            - totalBoostedRP = 1800e18
            index = 4.382e16 + [5e18 SP / 1800 RP]
                  = 43826723671924909 + 2777777777777777
                  ~ 4.6604499e16 [46604501449702686]
         */

        uint256 numOfNftsStaked = 2;                            // both vaults have 2 NFTs staked
        uint256 vault1RP = user1Rp + user2Rp/2;                 
        uint256 vault2RP = user2Rp/2;                           
        uint256 boostFactor = pool.PRECISION_BASE() + (numOfNftsStaked * pool.NFT_MULTIPLIER());
        uint256 totalBoostedRp = (vault1RP * boostFactor / pool.PRECISION_BASE()) + (vault2RP * boostFactor / pool.PRECISION_BASE());

        uint256 indexDelta = 5 ether * 1E18 / totalBoostedRp;
        uint256 expectedIndex = distribution0_T41.index + indexDelta;
        console.log("distribution0_T41.index", distribution0_T41.index);
        console.log("indexDelta", indexDelta);
        console.log("expectedIndex", expectedIndex);
        assertEq(expectedIndex, 46604501449702686); // 4.382e16
        
        // dynamic
        assertEq(distribution.index, expectedIndex);    // 4.66e16
        assertEq(distribution.totalEmitted, distribution0_T41.totalEmitted + 5 ether);
        assertEq(distribution.lastUpdateTimeStamp, 46);
    }

    // vault1 accounts updated at T46; lastUpdate at t36 
    function testVault1Account0_T46() public {
        DataTypes.Distribution memory distribution = getDistribution(0);
        DataTypes.Vault memory vault1 = pool.getVault(vaultId1);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);
        
        /** T41 - T46
            stakedTokens: user1Moca + user2Moca/2
            stakedRp: user1Rp + user2Rp/2 
            stakedNfts: 2
         */

        // vault assets 
        uint256 stakedRp = vault1_T41.stakedRealmPoints;  
        uint256 stakedTokens = vault1_T41.stakedTokens;
        uint256 stakedNfts = vault1_T41.stakedNfts;

        uint256 boostedRp = vault1_T41.boostedRealmPoints;
        uint256 poolBoostedRp = vault1_T41.boostedRealmPoints + vault2_T41.boostedRealmPoints;

        uint256 prevVaultIndex = vault1Account0_T41.index;

        // check indices

            // calc. newly accrued rewards       
            uint256 newlyAccRewards = calculateRewards(boostedRp, distribution0_T46.index, prevVaultIndex, 1E18); 

            // newly accrued fees since last update: based on newlyAccRewards
            uint256 newlyAccCreatorFee = newlyAccRewards * 1000 / 10_000;
            uint256 newlyAccTotalNftFee = newlyAccRewards * 1000 / 10_000;         
            uint256 newlyAccRealmPointsFee = newlyAccRewards * 1000 / 10_000;
            
            // latest indices
            uint256 latestNftIndex = (newlyAccTotalNftFee / stakedNfts) + vault1Account0_T41.nftIndex;     // 4 nfts staked frm t31-t36
            uint256 latestRpIndex = (newlyAccRealmPointsFee * 1E18 / stakedRp) + vault1Account0_T41.rpIndex;

        // check indices
        assertEq(vaultAccount.index, distribution.index); // 46604501449702686 [4.66e16]
        assertEq(vaultAccount.nftIndex, latestNftIndex);       
        assertEq(vaultAccount.rpIndex, latestRpIndex);    

        // calc. accumulated rewards
        uint256 totalAccRewards = newlyAccRewards + vault1Account0_T41.totalAccRewards;
        // calc. accumulated fees
        uint256 latestAccCreatorFee = newlyAccCreatorFee + vault1Account0_T41.accCreatorRewards;
        uint256 latestAccTotalNftFee = newlyAccTotalNftFee + vault1Account0_T41.accNftStakingRewards;
        uint256 latestAccRealmPointsFee = newlyAccRealmPointsFee + vault1Account0_T41.accRealmPointsRewards;

        // heck accumulated rewards + fees
        assertEq(vaultAccount.totalAccRewards, totalAccRewards);
        assertEq(vaultAccount.accCreatorRewards, latestAccCreatorFee); 
        assertEq(vaultAccount.accNftStakingRewards, latestAccTotalNftFee); 
        assertEq(vaultAccount.accRealmPointsRewards, latestAccRealmPointsFee); 

        // rewardsAccPerUnitStaked: for moca stakers
        uint256 latestAccRewardsLessOfFees = newlyAccRewards - newlyAccCreatorFee - newlyAccTotalNftFee - newlyAccRealmPointsFee;
        uint256 expectedRewardsAccPerUnitStaked = (latestAccRewardsLessOfFees * 1E18 / stakedTokens) + vault1Account0_T41.rewardsAccPerUnitStaked;

        // rewardsAccPerUnitStaked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked); 

        // totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }
    
    function testVault2Account0_T46() public {
        DataTypes.Distribution memory distribution = getDistribution(0);
        DataTypes.Vault memory vault2 = pool.getVault(vaultId2);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 0);

        /** T41 - T46
            stakedTokens: user2Moca/2
            stakedRp: user2Rp/2
            stakedNfts: 2
         */

        // vault assets for t41-t46
        uint256 stakedRp = vault2_T41.stakedRealmPoints;  
        uint256 stakedTokens = vault2_T41.stakedTokens;
        uint256 stakedNfts = vault2_T41.stakedNfts;

        uint256 boostedRp = vault2_T41.boostedRealmPoints;
        uint256 poolBoostedRp = vault1_T41.boostedRealmPoints + vault2_T41.boostedRealmPoints;

        uint256 prevVaultIndex = vault2Account0_T41.index;

        // check indices

            // calc. newly accrued rewards       
            uint256 newlyAccRewards = calculateRewards(boostedRp, distribution0_T46.index, prevVaultIndex, 1E18); 
                // eval. rounding error
                uint256 emittedRewards = 5 ether;
                uint256 vault2ShareOfEmittedRewards = (boostedRp * emittedRewards) / poolBoostedRp;
                assertApproxEqAbs(newlyAccRewards, vault2ShareOfEmittedRewards, 466);

            // newly accrued fees since last update: based on newlyAccRewards
            uint256 newlyAccCreatorFee = newlyAccRewards * vault2_T41.creatorFeeFactor / 10_000;
            uint256 newlyAccTotalNftFee = newlyAccRewards * vault2_T41.nftFeeFactor / 10_000;         
            uint256 newlyAccRealmPointsFee = newlyAccRewards * vault2_T41.realmPointsFeeFactor / 10_000;

            // latest indices
            uint256 latestNftIndex = (newlyAccTotalNftFee / stakedNfts) + vault2Account0_T41.nftIndex;   
            uint256 latestRpIndex = (newlyAccRealmPointsFee * 1E18 / stakedRp) + vault2Account0_T41.rpIndex;

        // check indices
        assertEq(vaultAccount.index, distribution.index);
        assertEq(vaultAccount.nftIndex, latestNftIndex);       
        assertEq(vaultAccount.rpIndex, latestRpIndex);  

            // calc. accumulated rewards
            uint256 totalAccRewards = newlyAccRewards + vault2Account0_T41.totalAccRewards;
            // calc. accumulated fees
            uint256 latestAccCreatorFee = newlyAccCreatorFee + vault2Account0_T41.accCreatorRewards;
            uint256 latestAccTotalNftFee = newlyAccTotalNftFee + vault2Account0_T41.accNftStakingRewards;
            uint256 latestAccRealmPointsFee = newlyAccRealmPointsFee + vault2Account0_T41.accRealmPointsRewards;

        // check accumulated rewards + fees
        assertEq(vaultAccount.totalAccRewards, totalAccRewards, "totalAccRewards mismatch");
        assertEq(vaultAccount.accCreatorRewards, latestAccCreatorFee, "accCreatorRewards mismatch"); 
        assertEq(vaultAccount.accNftStakingRewards, latestAccTotalNftFee, "accNftStakingRewards mismatch"); 
        assertEq(vaultAccount.accRealmPointsRewards, latestAccRealmPointsFee, "accRealmPointsRewards mismatch"); 

            // rewardsAccPerUnitStaked: for moca stakers
            uint256 latestAccRewardsLessOfFees = newlyAccRewards - newlyAccCreatorFee - newlyAccTotalNftFee - newlyAccRealmPointsFee;
            uint256 expectedRewardsAccPerUnitStaked = (latestAccRewardsLessOfFees * 1E18 / stakedTokens) + vault2Account0_T41.rewardsAccPerUnitStaked;

        // rewardsAccPerUnitStaked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked, "rewardsAccPerUnitStaked mismatch"); 

        // totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0, "totalClaimedRewards mismatch");
    }

        // --------------- d0:vault1:users --------------- 

        function testUser1_ForVault1Account0_T46() public {
            DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId1, 0);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);  
            

        }

        function testUser2_ForVault1Account0_T46() public {

}