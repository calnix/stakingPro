// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT41.t.sol";

abstract contract StateT46_BothVaultsFeesUpdated_EndDistribution is StateT41_User2StakesToVault2 {

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
    DataTypes.UserAccount user1Vault1Account0_T46;
    DataTypes.UserAccount user1Vault1Account1_T46;
    //user2+vault1
    DataTypes.UserAccount user2Vault1Account0_T46;
    DataTypes.UserAccount user2Vault1Account1_T46;
    //user1+vault2
    DataTypes.UserAccount user1Vault2Account0_T46;
    DataTypes.UserAccount user1Vault2Account1_T46;
    //user2+vault2
    DataTypes.UserAccount user2Vault2Account0_T46;
    DataTypes.UserAccount user2Vault2Account1_T46;

    // additional
    uint256 user1Vault1ClaimableAtT41ViewFn;        

    function setUp() public virtual override {
        super.setUp();

        // changed
        vm.startPrank(operator);
            pool.endDistribution(1);
        vm.stopPrank();

        // snapshot T41 rewards:
        user1Vault1ClaimableAtT41ViewFn = pool.getClaimableRewards(user1, vaultId1, 1);

        // snapshot T41 rewards for user1+vault1: update both user and vault at T41
        vm.startPrank(user1);
            // Vault1 fees - user1 reduces creator fee, increases nft and rp fees
            uint256 creatorFeeFactor1 = 500; // Reduced from 1000
            uint256 nftFeeFactor1 = 1250;
            uint256 realmPointsFeeFactor1 = 1250;
            pool.updateVaultFees(vaultId1, nftFeeFactor1, creatorFeeFactor1, realmPointsFeeFactor1);
            
            // track T41 rewards: overwrites PoolT41.t.sol
            user1Vault1Account1_T41 = getUserAccount(user1, vaultId1, 1);
            vault1Account1_T41 = getVaultAccount(vaultId1, 1);  

        vm.stopPrank();


        vm.warp(46);
        
        // to update user at T46
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
        user1Vault1Account0_T46 = getUserAccount(user1, vaultId1, 0);
        user1Vault1Account1_T46 = getUserAccount(user1, vaultId1, 1);
        user2Vault1Account0_T46 = getUserAccount(user2, vaultId1, 0);
        user2Vault1Account1_T46 = getUserAccount(user2, vaultId1, 1);
        user1Vault2Account0_T46 = getUserAccount(user1, vaultId2, 0);
        user1Vault2Account1_T46 = getUserAccount(user1, vaultId2, 1);
        user2Vault2Account0_T46 = getUserAccount(user2, vaultId2, 0);
        user2Vault2Account1_T46 = getUserAccount(user2, vaultId2, 1);
    }
}

/** check vaults: T46
     assets remain unchanged from T41
     fees have been updated
    
    check accounts: T41-46
     vault1: rp: user1Rp + user2Rp/2 | tokens: user1Moca + user2Moca/2 | nfts: 2
     vault2: rp: user1Rp + user2Rp/2 | tokens: user1Moca + user2Moca/2 | nfts: 2

      - user1+vault1 updated
      - user2+vault2 updated
*/

/** changed
    check that rewards accrued are the same at T41
    no rewards accrued from T41 - T46
 */

contract StateT46_BothVaultsFeesUpdated_EndDistributionTest is StateT46_BothVaultsFeesUpdated_EndDistribution {

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

        // Check fee factors
        assertEq(vault1.nftFeeFactor, 1250);          // 10%
        assertEq(vault1.creatorFeeFactor, 500);       // 5%
        assertEq(vault1.realmPointsFeeFactor, 1250);  // 5%
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

        // Check fee factors
        assertEq(vault2.nftFeeFactor, 1125);          // 10%
        assertEq(vault2.creatorFeeFactor, 250);       // 5%
        assertEq(vault2.realmPointsFeeFactor, 625);  // 5%
    }

    // ---------------- distribution 1 ----------------
  
    function testDistribution1_T46() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        
        // static
        assertEq(distribution.distributionId, 1);
        assertEq(distribution.TOKEN_PRECISION, 1e18); 
        assertEq(distribution.endTime, 41);             // CHANGED
        assertEq(distribution.startTime, 21);
        assertEq(distribution.emissionPerSecond, 1 ether);
        assertEq(distribution.manuallyEnded, 1);        // CHANGED
        
        // note: emissions for T41-T46: 0. lastUpdate: 41

        // dynamic
        assertEq(distribution.index, distribution1_T41.index, "index mismatch");
        assertEq(distribution.totalEmitted, distribution1_T41.totalEmitted, "totalEmitted mismatch");
        assertEq(distribution.lastUpdateTimeStamp, 41, "lastUpdateTimeStamp mismatch");

        // vault received and distribution emitted should be the same        
        DataTypes.VaultAccount memory vaultAccount1 = getVaultAccount(vaultId1, 1);        
        DataTypes.VaultAccount memory vaultAccount2 = getVaultAccount(vaultId2, 1);

        assertApproxEqAbs(distribution.totalEmitted, vaultAccount1.totalAccRewards + vaultAccount2.totalAccRewards, 200, "totalEmitted mismatch");
    }

    // updated at T46; lastUpdated at T36
    function testVault1Account1_T46() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        DataTypes.Vault memory vault = pool.getVault(vaultId1);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);        

        // note: emissions for T41-T46: 0. lastUpdate: 36
        
        // vault assets: T41-T46
        uint256 stakedRp = user1Rp + user2Rp/2;  
        uint256 stakedTokens = user1Moca + user2Moca/2;
        uint256 stakedNfts = 2;
        // prev. vault index
        uint256 prevVaultIndex = vault1Account1_T36.index;
        // boosted tokens
        uint256 boostedTokens = vault1_T36.boostedStakedTokens;
        uint256 poolBoostedTokens = vault1_T36.boostedStakedTokens + vault2_T36.boostedStakedTokens; 

        // -------------- check indices --------------

            // calc. newly accrued rewards       
            uint256 newlyAccRewards = calculateRewards(boostedTokens, distribution.index, prevVaultIndex, 1E18); 

            // newly accrued fees since last update: based on newlyAccRewards
            uint256 newlyAccCreatorFee = newlyAccRewards * vault1_T36.creatorFeeFactor / 10_000;
            uint256 newlyAccTotalNftFee = newlyAccRewards * vault1_T36.nftFeeFactor / 10_000;         
            uint256 newlyAccRealmPointsFee = newlyAccRewards * vault1_T36.realmPointsFeeFactor / 10_000;
            
            // latest indices
            uint256 latestNftIndex = (newlyAccTotalNftFee / stakedNfts) + vault1Account1_T36.nftIndex;     
            uint256 latestRpIndex = (newlyAccRealmPointsFee * 1E18 / stakedRp) + vault1Account1_T36.rpIndex;
        
        assertEq(vaultAccount.index, distribution.index, "vaultAccount index mismatch");
        assertEq(vaultAccount.nftIndex, latestNftIndex, "vaultAccount nftIndex mismatch");
        assertEq(vaultAccount.rpIndex, latestRpIndex, "vaultAccount rpIndex mismatch");
        
        // -------------- check accumulated rewards --------------

            // calc. accumulated rewards
            uint256 totalAccRewards = newlyAccRewards + vault1Account1_T36.totalAccRewards;
            // calc. accumulated fees
            uint256 latestAccCreatorFee = newlyAccCreatorFee + vault1Account1_T36.accCreatorRewards;
            uint256 latestAccTotalNftFee = newlyAccTotalNftFee + vault1Account1_T36.accNftStakingRewards;
            uint256 latestAccRealmPointsFee = newlyAccRealmPointsFee + vault1Account1_T36.accRealmPointsRewards;

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, totalAccRewards, "totalAccRewards mismatch");
        assertEq(vaultAccount.accCreatorRewards, latestAccCreatorFee, "accCreatorRewards mismatch");
        assertEq(vaultAccount.accNftStakingRewards, latestAccTotalNftFee, "accNftStakingRewards mismatch"); 
        assertEq(vaultAccount.accRealmPointsRewards, latestAccRealmPointsFee, "accRealmPointsRewards mismatch");

        // -------------- check rewardsAccPerUnitStaked --------------

            // rewardsAccPerUnitStaked: for moca stakers
            uint256 latestAccRewardsLessOfFees = newlyAccRewards - newlyAccCreatorFee - newlyAccTotalNftFee - newlyAccRealmPointsFee;
            uint256 expectedRewardsAccPerUnitStaked = (latestAccRewardsLessOfFees * 1E18 / stakedTokens) + vault1Account1_T36.rewardsAccPerUnitStaked;

        // Check rewardsAccPerUnitStaked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked, "rewardsAccPerUnitStaked mismatch");

        // Check totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0, "totalClaimedRewards mismatch");
    }

    function testVault2Account1_T46() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        DataTypes.Vault memory vault = pool.getVault(vaultId2);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 1);
        
        // note: emissions for T41-T46: 0. lastUpdate: 41

        // Check indices match distribution
        assertEq(vaultAccount.index, distribution1_T41.index, "vaultAccount index mismatch");
        assertEq(vaultAccount.nftIndex, vault2Account1_T41.nftIndex, "vaultAccount nftIndex mismatch");
        assertEq(vaultAccount.rpIndex, vault2Account1_T41.rpIndex, "vaultAccount rpIndex mismatch");
        
        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, vault2Account1_T41.totalAccRewards, "totalAccRewards mismatch");
        assertEq(vaultAccount.accCreatorRewards, vault2Account1_T41.accCreatorRewards, "accCreatorRewards mismatch");
        assertEq(vaultAccount.accNftStakingRewards, vault2Account1_T41.accNftStakingRewards, "accNftStakingRewards mismatch"); 
        assertEq(vaultAccount.accRealmPointsRewards, vault2Account1_T41.accRealmPointsRewards, "accRealmPointsRewards mismatch");
        
        // Check rewardsAccPerUnitStaked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, vault2Account1_T41.rewardsAccPerUnitStaked, "rewardsAccPerUnitStaked mismatch");
        
        // Check totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0, "totalClaimedRewards mismatch");
    }

        // --------------- d1:vault1:users ---------------

        function testUser1_ForVault1Account1_T46p() public {
            DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId1, 1);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);  

            //--- user1+vault1 last updated at t36: consider the emissions from t36-t46
            uint256 stakedRP = user1Rp;
            uint256 stakedTokens = user1Moca;
            uint256 numOfNfts = 0; 

            // Check indices match vault@t46
            assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked, "userIndex mismatch");
            assertEq(userAccount.nftIndex, vaultAccount.nftIndex, "nftIndex mismatch");
            assertEq(userAccount.rpIndex, vaultAccount.rpIndex, "rpIndex mismatch");

            // Check accumulated rewards
                uint256 prevUserIndex = user1Vault1Account1_T36.index;
                uint256 prevNftIndex = user1Vault1Account1_T36.nftIndex;
                uint256 prevRpIndex = user1Vault1Account1_T36.rpIndex;
                uint256 prevAccStakingRewards = user1Vault1Account1_T36.accStakingRewards;
                uint256 prevAccNftStakingRewards = user1Vault1Account1_T36.accNftStakingRewards;
                uint256 prevAccRealmPointsRewards = user1Vault1Account1_T36.accRealmPointsRewards;
                
                // Calculate expected rewards for user1's staked tokens 
                uint256 latestAccStakingRewards = calculateRewards(stakedTokens, vaultAccount.rewardsAccPerUnitStaked, prevUserIndex, 1E18) + prevAccStakingRewards;      
                // Calculate expected rewards for nft staking
                uint256 latestAccNftStakingRewards = ((vaultAccount.nftIndex - prevNftIndex) * numOfNfts) + prevAccNftStakingRewards; 
                // Calculate expected rewards for rp staking
                uint256 latestAccRealmPointsRewards = calculateRewards(stakedRP, vaultAccount.rpIndex, prevRpIndex, 1E18) + prevAccRealmPointsRewards;

            assertEq(userAccount.accStakingRewards, latestAccStakingRewards, "accStakingRewards mismatch"); 
            assertEq(userAccount.accNftStakingRewards, latestAccNftStakingRewards, "accNftStakingRewards mismatch"); // 0
            assertEq(userAccount.accRealmPointsRewards, latestAccRealmPointsRewards, "accRealmPointsRewards mismatch");
        
            // Check claimed rewards: token rewards can be claimed
            assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
            assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
            assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
            assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");  //user1 is vault1 creator

            //--------------------------------
            
            // view fn: user1 gets their share of total rewards
            uint256 claimableRewards = pool.getClaimableRewards(user1, vaultId1, 1);
            
            uint256 expectedClaimableRewards = latestAccStakingRewards + latestAccNftStakingRewards + latestAccRealmPointsRewards;
            if (user1 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

            assertEq(claimableRewards, expectedClaimableRewards, "claimableRewards mismatch"); 
        }

        // stale: user2's account was last updated at t36
        /*function testUser2_ForVault1Account1_T46() public {
            DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId1, 1);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);

            //--- user2+vault1: last updated at t41
            uint256 stakedRP = user2Rp/2;
            uint256 stakedTokens = user2Moca/2; 
            uint256 numOfNfts = 2; 

            // Check indices match vault@t46
            assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked, "userIndex mismatch");
            assertEq(userAccount.nftIndex, vaultAccount.nftIndex, "nftIndex mismatch");
            assertEq(userAccount.rpIndex, vaultAccount.rpIndex, "rpIndex mismatch");

            // Check accumulated rewards

                // Calculate expected rewards for user2's staked tokens 
                uint256 prevUserIndex = user2Account1_T41.index;
                uint256 prevAccStakingRewards = user2Account1_T41.accStakingRewards;
                uint256 latestAccStakingRewards = calculateRewards(stakedTokens, vaultAccount.rewardsAccPerUnitStaked, prevUserIndex, 1E18) + prevAccStakingRewards;     

                // Calculate expected rewards for nft staking
                uint256 prevAccNftStakingRewards = user2Account1_T41.accNftStakingRewards;
                uint256 latestAccNftStakingRewards = ((vaultAccount.nftIndex - user2Account1_T41.nftIndex) * numOfNfts) + prevAccNftStakingRewards; 
                // Calculate expected rewards for rp staking
                uint256 prevRpIndex = user2Account1_T41.rpIndex;
                uint256 prevAccRealmPointsRewards = user2Account1_T41.accRealmPointsRewards;
                uint256 latestAccRealmPointsRewards = calculateRewards(stakedRP, vaultAccount.rpIndex, prevRpIndex, 1E18) + prevAccRealmPointsRewards;

            assertEq(userAccount.accStakingRewards, latestAccStakingRewards, "accStakingRewards mismatch"); 
            assertEq(userAccount.accNftStakingRewards, latestAccNftStakingRewards, "accNftStakingRewards mismatch");
            assertEq(userAccount.accRealmPointsRewards, latestAccRealmPointsRewards, "accRealmPointsRewards mismatch");

            // Check claimed rewards: staking power cannot be claimed
            assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
            assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
            assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
            assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");   //user 2 did not create vault1

            
            //--------------------------------
            
            // view fn: user1 gets their share of total rewards
            uint256 claimableRewards = pool.getClaimableRewards(user2, vaultId1, 1);
            
            uint256 expectedClaimableRewards = latestAccStakingRewards + latestAccNftStakingRewards + latestAccRealmPointsRewards;
            if (user2 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

            assertEq(claimableRewards, expectedClaimableRewards, "claimableRewards mismatch"); 
        }*/


        // --------------- d1:vault2:users ---------------

        // user1 does not have any assets in vault2
        function testUser1_ForVault2Account1_T46() public {
            DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId2, 1);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 1);

            //--- user1+vault2
            uint256 stakedRP = 0;
            uint256 stakedTokens = 0;
            uint256 numOfNfts = 0; 

            // should show 0 for all values
            
            assertEq(userAccount.index, 0, "userIndex mismatch");
            assertEq(userAccount.nftIndex, 0, "nftIndex mismatch");
            assertEq(userAccount.rpIndex, 0, "rpIndex mismatch");

            assertEq(userAccount.accStakingRewards, 0, "accStakingRewards mismatch"); 
            assertEq(userAccount.accNftStakingRewards, 0, "accNftStakingRewards mismatch");
            assertEq(userAccount.accRealmPointsRewards, 0, "accRealmPointsRewards mismatch");

            assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
            assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
            assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
            assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");

            //--------------------------------
            
            // view fn: user1 gets their share of total rewards
            uint256 claimableRewards = pool.getClaimableRewards(user1, vaultId2, 1);           
            assertEq(claimableRewards, 0, "claimableRewards mismatch"); 
        }

        function testUser2_ForVault2Account1_T46() public {
            DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId2, 1);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 1);

            // Check indices match vault@t46
            assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked, "userIndex mismatch");
            assertEq(userAccount.nftIndex, vaultAccount.nftIndex, "nftIndex mismatch");
            assertEq(userAccount.rpIndex, vaultAccount.rpIndex, "rpIndex mismatch");

            // Check accumulated rewards
            assertEq(userAccount.accStakingRewards, user2Vault2Account1_T41.accStakingRewards, "accStakingRewards mismatch");
            assertEq(userAccount.accNftStakingRewards, user2Vault2Account1_T41.accNftStakingRewards, "accNftStakingRewards mismatch");
            assertEq(userAccount.accRealmPointsRewards, user2Vault2Account1_T41.accRealmPointsRewards, "accRealmPointsRewards mismatch");

            // Check claimed rewards: token rewards are claimable
            assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
            assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
            assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
            assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch"); // user2 is vault2 creator

            //--------------------------------
            
            // view fn: user2 gets their share of total rewards
            uint256 claimableRewards = pool.getClaimableRewards(user2, vaultId2, 1);
            
            uint256 expectedClaimableRewards = user2Vault2Account1_T41.accStakingRewards + user2Vault2Account1_T41.accNftStakingRewards + user2Vault2Account1_T41.accRealmPointsRewards;
            if (user2 == pool.getVault(vaultId2).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

            assertEq(claimableRewards, expectedClaimableRewards, "claimableRewards mismatch"); 
        }

    //--------------------------------

    // claim rewards
    function testUser1_ClaimDistribution1_Vault1_T46() public {
        
        // rewards at t41
        uint256 AccruedAtT41 = user1Vault1Account1_T41.accStakingRewards + user1Vault1Account1_T41.accNftStakingRewards + user1Vault1Account1_T41.accRealmPointsRewards + vault1Account1_T41.accCreatorRewards;
        uint256 claimedAtT41 = user1Vault1Account1_T41.claimedStakingRewards + user1Vault1Account1_T41.claimedNftRewards + user1Vault1Account1_T41.claimedRealmPointsRewards + user1Vault1Account1_T41.claimedCreatorRewards; 
        uint256 claimableAtT41 = AccruedAtT41 - claimedAtT41;

        // rewards at t46
        uint256 AccruedAtT46 = user1Vault1Account1_T46.accStakingRewards + user1Vault1Account1_T46.accNftStakingRewards + user1Vault1Account1_T46.accRealmPointsRewards + vault1Account1_T46.accCreatorRewards;
        uint256 claimedAtT46 = user1Vault1Account1_T46.claimedStakingRewards + user1Vault1Account1_T46.claimedNftRewards + user1Vault1Account1_T46.claimedRealmPointsRewards + user1Vault1Account1_T46.claimedCreatorRewards; 
        uint256 claimableAtT46 = AccruedAtT46 - claimedAtT46;

        // Get user's token balance before claiming
        uint256 userBalanceBefore = rewardsToken1.balanceOf(user1);

        // Claim rewards
        vm.startPrank(user1);
        pool.claimRewards(vaultId1, 1);
        vm.stopPrank();

        // Get user's token balance after claiming
        uint256 userBalanceAfter = rewardsToken1.balanceOf(user1);

        // Check claimed amount matches claimable amount
        assertEq(user1Vault1ClaimableAtT41ViewFn, claimableAtT41, "totalClaimedRewards mismatch");
        
        // No further rewards accrued after D1 ended
        assertEq(claimableAtT41, claimableAtT46, "T41<>T46 mismatch"); // 8.083e18

        // Check that tokens were actually transferred to user
        assertEq(userBalanceAfter - userBalanceBefore, user1Vault1ClaimableAtT41ViewFn, "token transfer amount mismatch");
    }

    function testUser2_ClaimDistribution1_Vault2_T46() public {
        // Get claimable rewards before claiming
        uint256 claimableRewardsViewFn = pool.getClaimableRewards(user2, vaultId2, 1);

        // rewards at t41
        uint256 AccruedAtT41 = user2Vault2Account1_T41.accStakingRewards + user2Vault2Account1_T41.accNftStakingRewards + user2Vault2Account1_T41.accRealmPointsRewards + vault2Account1_T41.accCreatorRewards;
        uint256 claimedAtT41 = user2Vault2Account1_T41.claimedStakingRewards + user2Vault2Account1_T41.claimedNftRewards + user2Vault2Account1_T41.claimedRealmPointsRewards + user2Vault2Account1_T41.claimedCreatorRewards; 
        uint256 claimableAtT41 = AccruedAtT41 - claimedAtT41;

        // rewards at t46
        uint256 AccruedAtT46 = user2Vault2Account1_T46.accStakingRewards + user2Vault2Account1_T46.accNftStakingRewards + user2Vault2Account1_T46.accRealmPointsRewards + vault2Account1_T46.accCreatorRewards;
        uint256 claimedAtT46 = user2Vault2Account1_T46.claimedStakingRewards + user2Vault2Account1_T46.claimedNftRewards + user2Vault2Account1_T46.claimedRealmPointsRewards + user2Vault2Account1_T46.claimedCreatorRewards; 
        uint256 claimableAtT46 = AccruedAtT46 - claimedAtT46;

        // Get user's token balance before claiming
        uint256 userBalanceBefore = rewardsToken1.balanceOf(user2);

        // Claim rewards
        vm.startPrank(user2);
        pool.claimRewards(vaultId2, 1);
        vm.stopPrank();

        // Get user's token balance after claiming
        uint256 userBalanceAfter = rewardsToken1.balanceOf(user2);

        // Check view fn
        assertEq(claimableRewardsViewFn, claimableAtT41, "totalClaimedRewards mismatch");

        // No further rewards accrued after D1 ended
        assertEq(claimableAtT41, claimableAtT46, "T41<>T46 mismatch"); 
        
        // Check that tokens were actually transferred to user
        assertEq(userBalanceAfter - userBalanceBefore, claimableRewardsViewFn, "token transfer amount mismatch");
    }
    

}