// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT1.t.sol";

abstract contract StateT6_User2StakeAssetsToVault1 is StateT1_User1StakeAssetsToVault1 {

    // for reference
    DataTypes.Distribution distribution0_T6;
    DataTypes.VaultAccount vault1Account0_T6;
    DataTypes.UserAccount user1Account0_T6;
    DataTypes.UserAccount user2Account0_T6;

    function setUp() public virtual override {
        super.setUp();

        // T6   
        vm.warp(6);
 
        vm.startPrank(user2);
        
        // User2 stakes half their tokens
        mocaToken.approve(address(pool), user2Moca/2);
        pool.stakeTokens(vaultId1, user2Moca/2);

        // User2 stakes 2 nfts
        uint256[] memory nftsToStake = new uint256[](2); 
        nftsToStake[0] = user2NftsArray[0];
        nftsToStake[1] = user2NftsArray[1];
        pool.stakeNfts(vaultId1, nftsToStake);
        
        // User2 stakes half their RP
        uint256 expiry = block.timestamp + 1 days;
        uint256 nonce = 0;
        bytes memory signature = generateSignature(user2, vaultId1, user2Rp/2, expiry, nonce);
        pool.stakeRP(vaultId1, user2Rp/2, expiry, signature);

        vm.stopPrank();

        // save state
        distribution0_T6 = getDistribution(0);
        vault1Account0_T6 = getVaultAccount(vaultId1, 0);
        user1Account0_T6 = getUserAccount(user1, vaultId1, 0);
        user2Account0_T6 = getUserAccount(user2, vaultId1, 0);
    }
}


//note: 5 seconds delta. 5 ether of staking power emitted @1ether/second
contract StateT6_User2StakeAssetsToVault1Test is StateT6_User2StakeAssetsToVault1 {
    // ---------------- distribution 0 ----------------

    function testPool_T6() public {

        // Check total staked assets
        assertEq(pool.totalCreationNfts(), user1NftsArray.length);
        assertEq(pool.totalStakedNfts(), 2); // user2's 2 staked NFTs
        assertEq(pool.totalStakedTokens(), user1Moca/2 + user2Moca/2);
        assertEq(pool.totalStakedRealmPoints(), user1Rp/2 + user2Rp/2);

        // Check boosted balances
        uint256 expectedBoostFactor = 10_000 + (2 * nftMultiplier); // Base + 2 NFTs from user2
        uint256 expectedBoostedRealmPoints = ((user1Rp/2 + user2Rp/2) * expectedBoostFactor) / 10_000;
        uint256 expectedBoostedStakedTokens = ((user1Moca/2 + user2Moca/2) * expectedBoostFactor) / 10_000;

        assertEq(pool.totalBoostedRealmPoints(), expectedBoostedRealmPoints);
        assertEq(pool.totalBoostedStakedTokens(), expectedBoostedStakedTokens);
    }

    function testDistribution0_T6() public {
        DataTypes.Distribution memory distribution = getDistribution(0);

        /** index calc.
            totalStakedRp = user1Rp/2 = 250 RP
            totalEmitted = 5 SP
            index = 5 SP / 250 RP = 0.02 * 1E18
         */
        uint256 expectedIndex = 0.02 * 1E18;

        assertEq(distribution.index, expectedIndex);
        assertEq(distribution.lastUpdateTimeStamp, 6);
        assertEq(distribution.emissionPerSecond, 1 ether);
        assertEq(distribution.endTime, 0);
    }

    function testVault1_T6() public {
        DataTypes.Vault memory vault = pool.getVault(vaultId1);
        
        // Base vault data
        assertEq(vault.creator, user1);
        assertEq(vault.startTime, startTime);
        assertEq(vault.endTime, 0);
        assertEq(vault.removed, 0);
        assertEq(vault.nftFeeFactor, 1000);
        assertEq(vault.creatorFeeFactor, 1000);
        assertEq(vault.realmPointsFeeFactor, 1000);
        
        // Verify creation NFTs
        assertEq(vault.creationTokenIds.length, user1NftsArray.length);
        for(uint i = 0; i < user1NftsArray.length; i++) {
            assertEq(vault.creationTokenIds[i], user1NftsArray[i]);
        }

        // Verify staked assets
        assertEq(vault.stakedTokens, user1Moca/2 + user2Moca/2);
        assertEq(vault.stakedNfts, 2);
        assertEq(vault.stakedRealmPoints, user1Rp/2 + user2Rp/2);

        // Verify boosted balances
        uint256 expectedBoostFactor = 10_000 + (2 * nftMultiplier);
        assertEq(vault.totalBoostFactor, expectedBoostFactor);
        assertEq(vault.boostedRealmPoints, (vault.stakedRealmPoints * vault.totalBoostFactor) / 10_000);
        assertEq(vault.boostedStakedTokens, (vault.stakedTokens * vault.totalBoostFactor) / 10_000);
    }

    function testVault1Account0_T6() public {
        DataTypes.Distribution memory distribution = getDistribution(0);
        DataTypes.Vault memory vault = pool.getVault(vaultId1);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);
        
        /** index calc:
            totalStakedRp = user1Rp/2 = 250 RP
            totalEmitted = 5 SP
            index = 5 SP / 250 RP = 0.02 * 1E18

            vault1 fees:
                uint256 nftFeeFactor = 1000;
                uint256 creatorFeeFactor = 1000; 
                uint256 realmPointsFeeFactor = 1000;
            totalFees = 30% of total rewards [3000/10000 = 30/100]
         */
        uint256 totalAccRewards = 5 ether;
        uint256 expectedIndex = distribution.index;
        // expected fees
        uint256 expectedAccCreatorFee = totalAccRewards * 1000 / 10_000;
        uint256 expectedAccTotalNftFee = 0;                                     // 0 nfts staked frm t1-6
        uint256 expectedAccRealmPointsFee = totalAccRewards * 1000 / 10_000;

        // expected indices
        uint256 expectedNftIndex = 0;      // 0 nfts staked frm t1-6
        uint256 expectedRpIndex = expectedAccRealmPointsFee * 1E18 / (user1Rp/2);     // 250 RP staked

        // rewardsAccPerUnitStaked: for moca stakers
        uint256 totalRewardsLessOfFees = totalAccRewards - (expectedAccCreatorFee + expectedAccTotalNftFee + expectedAccRealmPointsFee);
        uint256 expectedRewardsAccPerUnitStaked = totalRewardsLessOfFees * 1E18 / (user1Moca/2);

        // Check indices
        assertEq(vaultAccount.index, expectedIndex); // must match distribution index
        assertEq(vaultAccount.nftIndex, expectedNftIndex); 
        assertEq(vaultAccount.rpIndex, expectedRpIndex);   

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, totalAccRewards);
        assertEq(vaultAccount.accCreatorRewards, expectedAccCreatorFee); 
        assertEq(vaultAccount.accNftStakingRewards, expectedAccTotalNftFee); 
        assertEq(vaultAccount.accRealmPointsRewards, expectedAccRealmPointsFee); 

        // rewardsAccPerUnitStaked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked); 

        // totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

    function testUser1_T6() public {
        DataTypes.User memory user = pool.getUser(user1, vaultId1);

        // nfts        
        assertEq(user.tokenIds.length, 0);

        // tokens
        assertEq(user.stakedTokens, user1Moca/2);

        // realm points
        assertEq(user.stakedRealmPoints, user1Rp/2);
    }

    function testUser1AccountForVault1_T6() public {

        DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId1, 0);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);

        //--- user 1 not updated. since he took no action at t6

        // Check indices
        assertEq(userAccount.index, 0);
        assertEq(userAccount.nftIndex, 0);
        assertEq(userAccount.rpIndex, 0);

        // Check accumulated rewards
        assertEq(userAccount.accStakingRewards, 0);
        assertEq(userAccount.accNftStakingRewards, 0);
        assertEq(userAccount.accRealmPointsRewards, 0);

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0);
        assertEq(userAccount.claimedNftRewards, 0);
        assertEq(userAccount.claimedRealmPointsRewards, 0);
        assertEq(userAccount.claimedCreatorRewards, 0);
        
        //--------------------------------
        
        // view fn: user1 gets all emitted rewards so far
        uint256 rewards = pool.getClaimableRewards(user1, vaultId1, 0);
        assertEq(rewards, vaultAccount.totalAccRewards);
    }

    function testUser2_T6() public {
        DataTypes.User memory user = pool.getUser(user2, vaultId1);

        // tokens
        assertEq(user.stakedTokens, user2Moca/2);

        // nfts
        assertEq(user.tokenIds.length, 2);
        assertEq(user.tokenIds[0], user2NftsArray[0]);
        assertEq(user.tokenIds[1], user2NftsArray[1]);
        
        // realm points
        assertEq(user.stakedRealmPoints, user2Rp/2);
    }

    function testUser2AccountForVault1_T6() public {

        DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId1, 0);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);

        //--- user 2 has no rewards since just staked at t6

        // Check indices match vault 
        assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked);
        assertEq(userAccount.nftIndex, vaultAccount.nftIndex);
        assertEq(userAccount.rpIndex, vaultAccount.rpIndex);

        // Check accumulated rewards
        assertEq(userAccount.accStakingRewards, 0);
        assertEq(userAccount.accNftStakingRewards, 0);
        assertEq(userAccount.accRealmPointsRewards, 0);

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0);
        assertEq(userAccount.claimedNftRewards, 0);
        assertEq(userAccount.claimedRealmPointsRewards, 0);
        assertEq(userAccount.claimedCreatorRewards, 0);
        
        //--------------------------------
        
        // view fn: user2 gets all emitted rewards so far
        uint256 rewards = pool.getClaimableRewards(user2, vaultId1, 0);
        assertEq(rewards, 0);
    }

    function testOperatorCanSetRewardsVault() public {
        
        vm.startPrank(operator);
            vm.expectEmit(true, false, false, false);
            emit RewardsVaultSet(address(0), address(rewardsVault));
            pool.setRewardsVault(address(rewardsVault));
        vm.stopPrank();

        assertEq(address(pool.REWARDS_VAULT()), address(rewardsVault));
    }
}
