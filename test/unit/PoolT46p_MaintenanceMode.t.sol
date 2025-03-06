// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT41.t.sol";

abstract contract StateT46p_MaintenanceMode is StateT41_User2StakesToVault2 {


    function setUp() public virtual override {
        super.setUp();

        /**
            user 2 staked assets in vault2 at T41
         */

        vm.warp(46);

        vm.startPrank(operator);
            pool.enableMaintenance();
        vm.stopPrank();

    }
}

contract StateT46p_MaintenanceModeTest is StateT46p_MaintenanceMode {

    function testPool_InMaintenanceMode() public {
        assertEq(pool.isUnderMaintenance(), 1);
    }

    function testOperatorCanUpdateDistributions() public {
        
        // check distributions before
        DataTypes.Distribution memory distribution0Before = getDistribution(0);
        DataTypes.Distribution memory distribution1Before = getDistribution(1);
        
        vm.startPrank(operator);
            vm.expectEmit(true, true, true, true);
            uint256[] memory distributionIds = new uint256[](2);
            distributionIds[0] = 0;
            distributionIds[1] = 1;
            emit DistributionsUpdated(distributionIds);
            pool.updateDistributions();
        vm.stopPrank();

        // check distributions after
        DataTypes.Distribution memory distribution0After = getDistribution(0);
        DataTypes.Distribution memory distribution1After = getDistribution(1);

        // verify distributions were updated
        assertEq(distribution0Before.lastUpdateTimeStamp, 41);
        assertEq(distribution1Before.lastUpdateTimeStamp, 41);
        assertEq(distribution0After.lastUpdateTimeStamp, 46);
        assertEq(distribution1After.lastUpdateTimeStamp, 46);
    }
}


abstract contract StateT46p_MaintenanceMode_UpdateDistributions is StateT46p_MaintenanceMode {

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(operator);
            pool.updateDistributions();
        vm.stopPrank();
    }
}

contract StateT46p_MaintenanceMode_UpdateDistributionsTest is StateT46p_MaintenanceMode_UpdateDistributions {

    function testOperatorCanUpdateAllVaultAccounts() public {
        // check vaults before
        DataTypes.VaultAccount memory vault1Before = getVaultAccount(vaultId1, 1);
        DataTypes.VaultAccount memory vault2Before = getVaultAccount(vaultId2, 1);

        bytes32[] memory vaultIds = new bytes32[](2);
        vaultIds[0] = vaultId1;
        vaultIds[1] = vaultId2;
            
        vm.startPrank(operator);
            vm.expectEmit(true, true, true, true);
            emit VaultAccountsUpdated(vaultIds);
            pool.updateAllVaultAccounts(vaultIds);
        vm.stopPrank();

        // check vaults after
        DataTypes.VaultAccount memory vault1After = getVaultAccount(vaultId1, 1);
        DataTypes.VaultAccount memory vault2After = getVaultAccount(vaultId2, 1);

        // verify vaults were updated
        assertGt(vault1After.index, vault1Before.index);
        assertGt(vault2After.index, vault2Before.index);
    }
}


abstract contract StateT46p_MaintenanceMode_VaultAccountsUpdated is StateT46p_MaintenanceMode_UpdateDistributions {

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

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(operator);
            bytes32[] memory vaultIds = new bytes32[](2);
            vaultIds[0] = vaultId1;
            vaultIds[1] = vaultId2;
            pool.updateAllVaultAccounts(vaultIds);
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


contract StateT46p_MaintenanceMode_VaultAccountsUpdatedTest is StateT46p_MaintenanceMode_VaultAccountsUpdated {

    // updated at T46; lastUpdated at T36
    function testVault1Account1_T46_MaintenanceMode() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        DataTypes.Vault memory vault = pool.getVault(vaultId1);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);        

        /** T41 - T46
            stakedTokens: user1Moca + user2Moca/2
            stakedRp: user1Rp + user2Rp/2 
            stakedNfts: 2
         */

        // vault assets: T41-T46
        uint256 stakedRp = user1Rp + user2Rp/2;  
        uint256 stakedTokens = user1Moca + user2Moca/2;
        uint256 stakedNfts = 2;
        // prev. vault index
        uint256 prevVaultIndex = vault1Account1_T41.index;
        // boosted tokens
        uint256 boostedTokens = vault1_T41.boostedStakedTokens;
        uint256 poolBoostedTokens = vault1_T41.boostedStakedTokens + vault2_T41.boostedStakedTokens; 

        // -------------- check indices --------------

            // calc. newly accrued rewards       
            uint256 newlyAccRewards = calculateRewards(boostedTokens, distribution.index, prevVaultIndex, 1E18); 

            // newly accrued fees since last update: based on newlyAccRewards
            uint256 newlyAccCreatorFee = newlyAccRewards * vault1_T41.creatorFeeFactor / 10_000;
            uint256 newlyAccTotalNftFee = newlyAccRewards * vault1_T41.nftFeeFactor / 10_000;         
            uint256 newlyAccRealmPointsFee = newlyAccRewards * vault1_T41.realmPointsFeeFactor / 10_000;
            
            // latest indices
            uint256 latestNftIndex = (newlyAccTotalNftFee / stakedNfts) + vault1Account1_T41.nftIndex;     
            uint256 latestRpIndex = (newlyAccRealmPointsFee * 1E18 / stakedRp) + vault1Account1_T41.rpIndex;

        // Check indices match distribution
        assertEq(vaultAccount.index, distribution.index, "vaultAccount index mismatch");
        assertEq(vaultAccount.nftIndex, latestNftIndex, "vaultAccount nftIndex mismatch");
        assertEq(vaultAccount.rpIndex, latestRpIndex, "vaultAccount rpIndex mismatch");
    
        // -------------- check accumulated rewards --------------

            // calc. accumulated rewards
            uint256 totalAccRewards = newlyAccRewards + vault1Account1_T41.totalAccRewards;
            // calc. accumulated fees
            uint256 latestAccCreatorFee = newlyAccCreatorFee + vault1Account1_T41.accCreatorRewards;
            uint256 latestAccTotalNftFee = newlyAccTotalNftFee + vault1Account1_T41.accNftStakingRewards;
            uint256 latestAccRealmPointsFee = newlyAccRealmPointsFee + vault1Account1_T41.accRealmPointsRewards;

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, totalAccRewards, "totalAccRewards mismatch");
        assertEq(vaultAccount.accCreatorRewards, latestAccCreatorFee, "accCreatorRewards mismatch");
        assertEq(vaultAccount.accNftStakingRewards, latestAccTotalNftFee, "accNftStakingRewards mismatch"); 
        assertEq(vaultAccount.accRealmPointsRewards, latestAccRealmPointsFee, "accRealmPointsRewards mismatch");

        // -------------- check rewardsAccPerUnitStaked --------------

            // rewardsAccPerUnitStaked: for moca stakers
            uint256 latestAccRewardsLessOfFees = newlyAccRewards - newlyAccCreatorFee - newlyAccTotalNftFee - newlyAccRealmPointsFee;
            uint256 expectedRewardsAccPerUnitStaked = (latestAccRewardsLessOfFees * 1E18 / stakedTokens) + vault1Account1_T41.rewardsAccPerUnitStaked;

        // Check rewardsAccPerUnitStaked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked, "rewardsAccPerUnitStaked mismatch");

        // Check totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0, "totalClaimedRewards mismatch");
    }

    function testVault2Account1_T46_MaintenanceMode() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        DataTypes.Vault memory vault = pool.getVault(vaultId2);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 1);

        // vault assets: T41-T46
        uint256 stakedRp = user2Rp/2;  
        uint256 stakedTokens = user2Moca/2;
        uint256 stakedNfts = 2;
        // prev. vault index
        uint256 prevVaultIndex = vault2Account1_T41.index;
        // boosted tokens
        uint256 boostedTokens = vault2_T41.boostedStakedTokens;
        uint256 poolBoostedTokens = vault1_T41.boostedStakedTokens + vault2_T41.boostedStakedTokens; 

        // -------------- check indices --------------

            // calc. newly accrued rewards       
            uint256 newlyAccRewards = calculateRewards(boostedTokens, distribution.index, prevVaultIndex, 1E18); 

            // newly accrued fees since last update: based on newlyAccRewards
            uint256 newlyAccCreatorFee = newlyAccRewards * vault2_T41.creatorFeeFactor / 10_000;
            uint256 newlyAccTotalNftFee = newlyAccRewards * vault2_T41.nftFeeFactor / 10_000;         
            uint256 newlyAccRealmPointsFee = newlyAccRewards * vault2_T41.realmPointsFeeFactor / 10_000;
            
            // latest indices
            uint256 latestNftIndex = (newlyAccTotalNftFee / stakedNfts) + vault2Account1_T41.nftIndex;     
            uint256 latestRpIndex = (newlyAccRealmPointsFee * 1E18 / stakedRp) + vault2Account1_T41.rpIndex;

        // Check indices match distribution at t41
        assertEq(vaultAccount.index, distribution.index, "vaultAccount index mismatch");
        assertEq(vaultAccount.nftIndex, latestNftIndex, "vaultAccount nftIndex mismatch");
        assertEq(vaultAccount.rpIndex, latestRpIndex, "vaultAccount rpIndex mismatch");
        
        // -------------- check accumulated rewards --------------

            // calc. accumulated rewards
            uint256 totalAccRewards = newlyAccRewards + vault2Account1_T41.totalAccRewards;
            // calc. accumulated fees
            uint256 latestAccCreatorFee = newlyAccCreatorFee + vault2Account1_T41.accCreatorRewards;
            uint256 latestAccTotalNftFee = newlyAccTotalNftFee + vault2Account1_T41.accNftStakingRewards;
            uint256 latestAccRealmPointsFee = newlyAccRealmPointsFee + vault2Account1_T41.accRealmPointsRewards;

        assertEq(vaultAccount.totalAccRewards, totalAccRewards, "totalAccRewards mismatch");
        assertEq(vaultAccount.accCreatorRewards, latestAccCreatorFee, "accCreatorRewards mismatch");
        assertEq(vaultAccount.accNftStakingRewards, latestAccTotalNftFee, "accNftStakingRewards mismatch"); 
        assertEq(vaultAccount.accRealmPointsRewards, latestAccRealmPointsFee, "accRealmPointsRewards mismatch");
        
        // -------------- check rewardsAccPerUnitStaked --------------

            // rewardsAccPerUnitStaked: for moca stakers
            uint256 latestAccRewardsLessOfFees = newlyAccRewards - newlyAccCreatorFee - newlyAccTotalNftFee - newlyAccRealmPointsFee;
            uint256 expectedRewardsAccPerUnitStaked = (latestAccRewardsLessOfFees * 1E18 / stakedTokens) + vault2Account1_T41.rewardsAccPerUnitStaked;

        assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked, "rewardsAccPerUnitStaked mismatch");

        // Check totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0, "totalClaimedRewards mismatch");
    }

    function testUserCannotUpdateNftMultiplier() public {
        vm.startPrank(user1);
            vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, pool.OPERATOR_ROLE()));
            pool.updateNftMultiplier(100);
        vm.stopPrank();
    }

    function testOperatorCanUpdateNftMultiplier() public {
        uint256 oldNftMultiplier = pool.NFT_MULTIPLIER();
        uint256 newNftMultiplier = oldNftMultiplier * 2;

        vm.startPrank(operator);
            vm.expectEmit(true, true, true, true);
            emit NftMultiplierUpdated(oldNftMultiplier, newNftMultiplier);
            pool.updateNftMultiplier(newNftMultiplier);
        vm.stopPrank();
    }
}


abstract contract StateT46p_MaintenanceMode_NftMultiplierUpdated is StateT46p_MaintenanceMode_VaultAccountsUpdated {

    uint256 oldNftMultiplier;
    uint256 newNftMultiplier;

    function setUp() public virtual override {
        super.setUp();

        oldNftMultiplier = pool.NFT_MULTIPLIER();
        newNftMultiplier = oldNftMultiplier * 2;

        vm.startPrank(operator);
            pool.updateNftMultiplier(newNftMultiplier);
        vm.stopPrank();
    }
}

contract StateT46p_MaintenanceMode_NftMultiplierUpdatedTest is StateT46p_MaintenanceMode_NftMultiplierUpdated {

    function testNftMultiplierUpdated() public {
        assertEq(pool.NFT_MULTIPLIER(), newNftMultiplier, "nft multiplier not updated");
    }
}


abstract contract StateT46p_MaintenanceMode_UpdateBoostedBalances is StateT46p_MaintenanceMode_NftMultiplierUpdated {

}
