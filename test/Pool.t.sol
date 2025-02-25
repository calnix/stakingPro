// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import "./TestingHarness.sol";

abstract contract StateT0_Deploy is TestingHarness {    

    function setUp() public virtual override {
        super.setUp();
    }
}

contract StateT0_DeployTest is StateT0_Deploy {

    function testConstructor() public {
        assertEq(address(pool.NFT_REGISTRY()), address(nftRegistry));
        assertEq(address(pool.STAKED_TOKEN()), address(mocaToken));

        assertEq(pool.startTime(), startTime);

        assertEq(pool.NFT_MULTIPLIER(), nftMultiplier);
        assertEq(pool.CREATION_NFTS_REQUIRED(), creationNftsRequired);
        assertEq(pool.MINIMUM_REALMPOINTS_REQUIRED(), 250 ether);
        assertEq(pool.VAULT_COOLDOWN_DURATION(), vaultCoolDownDuration);
        assertEq(pool.STORED_SIGNER(), storedSigner);

        // CHECK ROLES
        assertEq(pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), owner), true);
        assertEq(pool.hasRole(pool.OPERATOR_ROLE(), owner), true);
        assertEq(pool.hasRole(pool.MONITOR_ROLE(), owner), true);

        assertEq(pool.hasRole(pool.MONITOR_ROLE(), monitor), true);
        assertEq(pool.hasRole(pool.OPERATOR_ROLE(), operator), true);
    }

    function testCannotCreateVault() public {
        vm.prank(user1);

        vm.expectRevert(Errors.NotStarted.selector);

        uint256 nftFeeFactor = 1000;
        uint256 creatorFeeFactor = 1000;
        uint256 realmPointsFeeFactor = 1000;
        pool.createVault(user1NftsArray, nftFeeFactor, creatorFeeFactor, realmPointsFeeFactor);
    }

    function testOperatorCanSetupDistribution() public {
        vm.prank(operator);
        
        // staking power
            uint256 distributionId = 0;
            uint256 distributionStartTime = 1;
            uint256 distributionEndTime;
            uint256 emissionPerSecond = 1 ether;
            uint256 tokenPrecision = 1E18;
            uint32 dstEid = 0;
            bytes32 tokenAddress = 0x00;
        pool.setupDistribution(distributionId, distributionStartTime, distributionEndTime, emissionPerSecond, tokenPrecision, dstEid, tokenAddress);        
    }

    /**
        note: test the other whenNotStarted
        - all stake fns
        - claim, etc
     */   
}

abstract contract StateT0_DeployAndSetupStakingPower is StateT0_Deploy {

    function setUp() public virtual override {
        super.setUp();

        vm.prank(operator);
        
        // staking power
            uint256 distributionId = 0;
            uint256 distributionStartTime = 1;
            uint256 distributionEndTime;
            uint256 emissionPerSecond = 1 ether;
            uint256 tokenPrecision = 1E18;
            uint32 dstEid = 3141;
            bytes32 tokenAddress = 0x00;
        pool.setupDistribution(distributionId, distributionStartTime, distributionEndTime, emissionPerSecond, tokenPrecision, dstEid, tokenAddress);        
    }
}

// TODO
contract StateT0_DeployAndSetupStakingPowerTest is StateT0_DeployAndSetupStakingPower {
    /**
        - test setupDistribution
        - test updateDistribution
        stuff you can can w/ distribvution, but before setup
    */
}


abstract contract StateT1_Started is StateT0_DeployAndSetupStakingPower {

    function setUp() public virtual override {
        super.setUp();

        //T1
        vm.warp(pool.startTime());
    }
}

contract StateT1_StartedTest is StateT1_Started {

    function testCannotStakeNftsToNonexistentVault() public {
        vm.prank(user2);
        bytes32 nonexistentVaultId = bytes32(uint256(1));
        uint256[] memory nftsToStake = new uint256[](1);
        nftsToStake[0] = user2NftsArray[0];

        vm.expectRevert(abi.encodeWithSelector(Errors.NonExistentVault.selector, nonexistentVaultId));
        pool.stakeNfts(nonexistentVaultId, nftsToStake);
    }

    function testCannotStakeTokensToNonexistentVault() public {
        vm.prank(user2);
        bytes32 nonexistentVaultId = bytes32(uint256(1));
        uint256 amount = 100 ether;

        vm.expectRevert(abi.encodeWithSelector(Errors.NonExistentVault.selector, nonexistentVaultId));
        pool.stakeTokens(nonexistentVaultId, amount);
    }

    function testCreateVault() public {
        vm.prank(user1);

            uint256 nftFeeFactor = 1000;
            uint256 creatorFeeFactor = 1000; 
            uint256 realmPointsFeeFactor = 1000;
            
        // Get vault ID before creating vault
        bytes32 expectedVaultId = generateVaultId(block.number - 1, user1);
        
        vm.expectEmit(true, true, true, true);
        emit VaultCreated(expectedVaultId, user1, nftFeeFactor, creatorFeeFactor, realmPointsFeeFactor);
        
        pool.createVault(user1NftsArray, nftFeeFactor, creatorFeeFactor, realmPointsFeeFactor);
        
        // Verify vault was created correctly
        DataTypes.Vault memory vault = pool.getVault(expectedVaultId);
        
        // Check creator and fee factors
        assertEq(vault.creator, user1, "Incorrect vault owner");
        assertEq(vault.nftFeeFactor, nftFeeFactor, "Incorrect NFT fee factor");
        assertEq(vault.creatorFeeFactor, creatorFeeFactor, "Incorrect creator fee factor");
        assertEq(vault.realmPointsFeeFactor, realmPointsFeeFactor, "Incorrect realm points fee factor");

        // Check creation NFTs array
        assertEq(vault.creationTokenIds.length, user1NftsArray.length, "Incorrect number of creation NFTs");
        for(uint i = 0; i < user1NftsArray.length; i++) {
            assertEq(vault.creationTokenIds[i], user1NftsArray[i], "Incorrect creation NFT ID");
        }

        // Check timestamps and status
        assertEq(vault.startTime, block.timestamp, "Incorrect start time");
        assertEq(vault.endTime, 0, "End time should be 0");
        assertEq(vault.removed, 0, "Vault should not be removed");

        // Check staking balances
        assertEq(vault.stakedNfts, 0, "Should have no staked NFTs");
        assertEq(vault.stakedTokens, 0, "Should have no staked tokens");
        assertEq(vault.stakedRealmPoints, 0, "Should have no staked realm points");

        // Check boost factors
        assertEq(vault.totalBoostFactor, 10_000, "Should have no boost factor");
        assertEq(vault.boostedRealmPoints, 0, "Should have no boosted realm points");
        assertEq(vault.boostedStakedTokens, 0, "Should have no boosted staked tokens");

        // Verify NFTs are registered to vault
        for(uint256 i = 0; i < user1NftsArray.length; i++) {
            (, bytes32 registeredVaultId) = nftRegistry.nfts(user1NftsArray[i]);
            assertEq(registeredVaultId, expectedVaultId, "NFT not registered to vault correctly");
        }
    }
}

// TODO
abstract contract StateT1_CreateVault1 is StateT1_Started {

    bytes32 public vaultId1 = 0x8fbe8a20f950b11703e51f11dee9f00d9fa0ebd091cc4f695909e860e994944b;

    function setUp() public virtual override {
        super.setUp();
        
        vm.prank(user1);

        uint256 nftFeeFactor = 1000;
        uint256 creatorFeeFactor = 1000; 
        uint256 realmPointsFeeFactor = 1000;

        pool.createVault(user1NftsArray, nftFeeFactor, creatorFeeFactor, realmPointsFeeFactor);
    }
}

contract StateT1_CreateVault1Test is StateT1_CreateVault1 {

    function testCannotCreateAnotherVaultWithLockedNfts() public {
        vm.prank(user1);
        vm.expectRevert();
        pool.createVault(user1NftsArray, 1000, 1000, 1000);
    }

    function testCannotStakeZeroTokens() public {
        vm.startPrank(user2);
        mocaToken.approve(address(pool), type(uint256).max);

        vm.expectRevert(Errors.InvalidAmount.selector);
        pool.stakeTokens(vaultId1, 0);
        vm.stopPrank();
    }

    function testVault1CreatedCorrectly() public {
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
        assertEq(vault.stakedTokens, 0);
        assertEq(vault.stakedNfts, 0);
        assertEq(vault.stakedRealmPoints, 0);

        // Verify boosted balances
        assertEq(vault.totalBoostFactor, 10_000);
        assertEq(vault.boostedRealmPoints, 0);
        assertEq(vault.boostedStakedTokens, 0);
    }

    function testCanStakeTokens() public {
        // Setup
        vm.startPrank(user2);
        uint256 stakeAmount = 100 ether;
        mocaToken.approve(address(pool), stakeAmount);

        // Get initial state
        DataTypes.Vault memory vaultBefore = pool.getVault(vaultId1);
        uint256 initialStakedTokens = vaultBefore.stakedTokens;
        uint256 userBalanceBefore = mocaToken.balanceOf(user2);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit StakedTokens(user2, vaultId1, stakeAmount);

        // Stake tokens
        pool.stakeTokens(vaultId1, stakeAmount);

        // Verify state changes
        DataTypes.Vault memory vaultAfter = pool.getVault(vaultId1);
        assertEq(vaultAfter.stakedTokens, initialStakedTokens + stakeAmount);
        assertEq(mocaToken.balanceOf(user2), userBalanceBefore - stakeAmount);
        assertEq(mocaToken.balanceOf(address(pool)), stakeAmount);
        vm.stopPrank();
    }

    function testCanStakeNfts() public {
        // Setup
        uint256[] memory nftsToStake = new uint256[](1);
        nftsToStake[0] = user2NftsArray[0];  // This should be 5 based on setup

        // Get initial state
        DataTypes.Vault memory vaultBefore = pool.getVault(vaultId1);
        uint256 initialStakedNfts = vaultBefore.stakedNfts;

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit StakedNfts(user2, vaultId1, nftsToStake);

        // Stake NFTs
        vm.prank(user2);
        pool.stakeNfts(vaultId1, nftsToStake);

        // Verify state changes
        DataTypes.Vault memory vaultAfter = pool.getVault(vaultId1);
        assertEq(vaultAfter.stakedNfts, initialStakedNfts + nftsToStake.length);
        
        // Verify NFT ownership using nfts mapping
        (, bytes32 registeredVaultId) = nftRegistry.nfts(nftsToStake[0]);
        assertEq(registeredVaultId, vaultId1, "NFT not registered to vault correctly");
        vm.stopPrank();
    }

    function testCanStakeRealmPoints() public {
        // Generate signature for realm points staking
        uint256 realmPointsAmount = 1000 ether;
        uint256 expiry = block.timestamp + 1 days;
        uint256 nonce = 0;
        bytes memory signature = generateSignature(user2, vaultId1, realmPointsAmount, expiry, nonce);


        // Get initial state
        DataTypes.Vault memory vaultBefore = pool.getVault(vaultId1);
        uint256 initialStakedPoints = vaultBefore.stakedRealmPoints;

        // Calculate boosted amount
        uint256 boostedAmount = (realmPointsAmount * vaultBefore.totalBoostFactor) / 10000;

        // Expect event with boosted amount
        vm.expectEmit(true, true, true, true);
        emit StakedRealmPoints(user2, vaultId1, realmPointsAmount, boostedAmount);

        // Stake realm points
        vm.prank(user2);
        pool.stakeRP(vaultId1, realmPointsAmount, expiry, signature);

        // Verify state changes
        DataTypes.Vault memory vaultAfter = pool.getVault(vaultId1);
        assertEq(vaultAfter.stakedRealmPoints, initialStakedPoints + realmPointsAmount);
        assertEq(vaultAfter.boostedRealmPoints, boostedAmount);
    }
}


abstract contract StateT1_User1StakeAssetsToVault1 is StateT1_CreateVault1 {

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(user1);

        // User1 stakes half their tokens
        mocaToken.approve(address(pool), user1Moca/2);
        pool.stakeTokens(vaultId1, user1Moca/2);

        // User1 stakes half their RP
        uint256 expiry = block.timestamp + 1 days;
        uint256 nonce = 0;
        bytes memory signature = generateSignature(user1, vaultId1, user1Rp/2, expiry, nonce);
        pool.stakeRP(vaultId1, user1Rp/2, expiry, signature);

        vm.stopPrank();
    }
}

// accounts only exist for distribution 0
contract StateT1_User1StakeAssetsToVault1Test is StateT1_User1StakeAssetsToVault1 {
    function testPool_T1() public {
        
        // Check total staked assets
        assertEq(pool.totalCreationNfts(), 5);
        assertEq(pool.totalStakedNfts(), 0); // No NFTs staked yet
        assertEq(pool.totalStakedTokens(), user1Moca/2);
        assertEq(pool.totalStakedRealmPoints(), user1Rp/2);

        // Check boosted balances
        uint256 expectedBoostFactor = 10_000; // Just base factor since no NFTs staked
        uint256 expectedBoostedRealmPoints = (user1Rp/2 * expectedBoostFactor) / 10_000;
        uint256 expectedBoostedStakedTokens = (user1Moca/2 * expectedBoostFactor) / 10_000;

        assertEq(pool.totalBoostedRealmPoints(), expectedBoostedRealmPoints);
        assertEq(pool.totalBoostedStakedTokens(), expectedBoostedStakedTokens);
    }

    function testVault1_T1() public {
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
        assertEq(vault.stakedTokens, user1Moca/2);
        assertEq(vault.stakedNfts, 0);
        assertEq(vault.stakedRealmPoints, user1Rp/2);

        // Verify boosted balances
        assertEq(vault.totalBoostFactor, 10_000);
        assertEq(vault.boostedRealmPoints, (vault.stakedRealmPoints * vault.totalBoostFactor) / 10_000);
        assertEq(vault.boostedStakedTokens, (vault.stakedTokens * vault.totalBoostFactor) / 10_000);
    }

    function testVault1Account0_T1() public {
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);

        // Check indices
        assertEq(vaultAccount.index, 0);
        assertEq(vaultAccount.nftIndex, 0);
        assertEq(vaultAccount.rpIndex, 0);

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, 0);
        assertEq(vaultAccount.accCreatorRewards, 0);
        assertEq(vaultAccount.accNftStakingRewards, 0);
        assertEq(vaultAccount.accRealmPointsRewards, 0);
        assertEq(vaultAccount.rewardsAccPerUnitStaked, 0);
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

    function testUser1_T1() public {
        DataTypes.User memory user = pool.getUser(user1, vaultId1);

        // nfts        
        assertEq(user.tokenIds.length, 0);

        // tokens
        assertEq(user.stakedTokens, user1Moca/2);

        // realm points
        assertEq(user.stakedRealmPoints, user1Rp/2);
    }

    function testUser1AccountForVault1_T1() public {

        DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId1, 0);

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
    }
}

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

//note: 5 seconds delta. another 5 ether of staking power emitted @1ether/second
abstract contract StateT11_Distribution1Created is StateT6_User2StakeAssetsToVault1 {

    function setUp() public virtual override {
        super.setUp();

        // T11   
        vm.warp(11);

        // distribution params
        uint256 distributionId = 1;
        uint256 distributionStartTime = 21;
        uint256 distributionEndTime = 21 + 100;
        uint256 emissionPerSecond = 1 ether;
        uint256 tokenPrecision = 1E18;
        bytes32 tokenAddress = rewardsVault.addressToBytes32(address(rewardsToken1));
        uint256 totalRequired = 100 * emissionPerSecond;

        // operator sets up distribution
        vm.startPrank(operator);
            // connect pool to rewardsVault
            pool.setRewardsVault(address(rewardsVault));

            // create distribution 1
            pool.setupDistribution(
                distributionId, 
                distributionStartTime, 
                distributionEndTime, 
                emissionPerSecond, 
                tokenPrecision,
                dstEid, tokenAddress
            );
        vm.stopPrank();

       
        // depositor mints, approves, deposits
        vm.startPrank(depositor);
            rewardsToken1.mint(depositor, totalRequired);
            rewardsToken1.approve(address(rewardsVault), totalRequired);
            rewardsVault.deposit(distributionId, totalRequired, depositor);
        vm.stopPrank();
    }
}

// TODO
contract StateT11_Distribution1CreatedTest is StateT11_Distribution1Created {

    /**TODO
        test post dstr setup stuff
     */

    // ---------------- distribution 1 ----------------

    function testDistribution1_T11() public {
        DataTypes.Distribution memory distribution = getDistribution(1);

        assertEq(distribution.distributionId, 1);
        assertEq(distribution.TOKEN_PRECISION, 1e18);

        assertEq(distribution.endTime, 121);
        assertEq(distribution.startTime, 21);
        assertEq(distribution.emissionPerSecond, 1 ether);

        assertEq(distribution.index, 0);
        assertEq(distribution.totalEmitted, 0);
        assertEq(distribution.lastUpdateTimeStamp, 21);
        
        assertEq(distribution.manuallyEnded, 0);
    }
}

abstract contract StateT16_BothUsersStakeAgain is StateT11_Distribution1Created {
    
    // for reference
    DataTypes.Distribution distribution0_T16;
    DataTypes.Distribution distribution1_T16;
    DataTypes.VaultAccount vault1Account0_T16;
    DataTypes.VaultAccount vault1Account1_T16;
    DataTypes.UserAccount user1Account0_T16;
    DataTypes.UserAccount user2Account0_T16;

    function setUp() public virtual override {
        super.setUp();

        // T16   
        vm.warp(16);
 
        // User1 stakes remaining assets
        vm.startPrank(user1);
        
            // Stake remaining tokens
            mocaToken.approve(address(pool), user1Moca/2);
            pool.stakeTokens(vaultId1, user1Moca/2);
            
            // Stake remaining RP
            uint256 expiry = block.timestamp + 1 days;
            uint256 nonce = 1;
            bytes memory signature = generateSignature(user1, vaultId1, user1Rp/2, expiry, nonce);
            pool.stakeRP(vaultId1, user1Rp/2, expiry, signature);

        vm.stopPrank();

        // User2 stakes remaining assets
        vm.startPrank(user2);
        
            // Stake remaining tokens
            mocaToken.approve(address(pool), user2Moca/2);
            pool.stakeTokens(vaultId1, user2Moca/2);

            // Stake 2 more nfts
            uint256[] memory nftsToStake = new uint256[](2); 
            nftsToStake[0] = user2NftsArray[2];
            nftsToStake[1] = user2NftsArray[3];
            pool.stakeNfts(vaultId1, nftsToStake);
            
            // Stake remaining RP
            expiry = block.timestamp + 1 days;
            nonce = 1;
            signature = generateSignature(user2, vaultId1, user2Rp/2, expiry, nonce);
            pool.stakeRP(vaultId1, user2Rp/2, expiry, signature);

        vm.stopPrank();

        // save state
        distribution0_T16 = getDistribution(0);
        distribution1_T16 = getDistribution(1);
        vault1Account0_T16 = getVaultAccount(vaultId1, 0);
        vault1Account1_T16 = getVaultAccount(vaultId1, 1);
        user1Account0_T16 = getUserAccount(user1, vaultId1, 0);
        user2Account0_T16 = getUserAccount(user2, vaultId1, 0);
    }
}

//note: 2 distributions created
contract StateT16_BothUsersStakeAgainTest is StateT16_BothUsersStakeAgain {

    //TODO: testPool_t16

    function testVault1_T16() public {
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
        assertEq(vault.stakedTokens, user1Moca + user2Moca);
        assertEq(vault.stakedNfts, 4);
        assertEq(vault.stakedRealmPoints, user1Rp + user2Rp);

        // Verify boosted balances
        uint256 expectedBoostFactor = 10_000 + (vault.stakedNfts * pool.NFT_MULTIPLIER());
        assertEq(vault.totalBoostFactor, expectedBoostFactor);
        assertEq(vault.boostedRealmPoints, (vault.stakedRealmPoints * vault.totalBoostFactor) / 10_000);
        assertEq(vault.boostedStakedTokens, (vault.stakedTokens * vault.totalBoostFactor) / 10_000);
    }

    function testUser1_T16() public {
        DataTypes.User memory user = pool.getUser(user1, vaultId1);

        // nfts        
        assertEq(user.tokenIds.length, 0);

        // tokens
        assertEq(user.stakedTokens, user1Moca);

        // realm points
        assertEq(user.stakedRealmPoints, user1Rp);
    }

    function testUser2_T16() public {
        DataTypes.User memory user = pool.getUser(user2, vaultId1);

        // nfts        
        assertEq(user.tokenIds.length, 4);
        assertEq(user.tokenIds[0], user2NftsArray[0]);
        assertEq(user.tokenIds[1], user2NftsArray[1]); 
        assertEq(user.tokenIds[2], user2NftsArray[2]);
        assertEq(user.tokenIds[3], user2NftsArray[3]);

        // tokens
        assertEq(user.stakedTokens, user2Moca);

        // realm points
        assertEq(user.stakedRealmPoints, user2Rp);
    }

    // ---------------- distribution 0 ----------------

    function testDistribution0_T16() public {

        DataTypes.Distribution memory distribution = getDistribution(0);

        // static
        assertEq(distribution.distributionId, 0);
        assertEq(distribution.TOKEN_PRECISION, 1e18); 
        assertEq(distribution.endTime, 0);
        assertEq(distribution.startTime, 1);
        assertEq(distribution.emissionPerSecond, 1 ether);
        assertEq(distribution.manuallyEnded, 0);        
        
        /** index calc:
            - prev. index: 0.02e18 [t6]
            - totalEmitted: 10e18 SP
            - totalRpStaked: (250 + 500) [t6-t16]
            - totalBoostFactor: 1000 * 2 / PRECISION_BASE = 20% [20/100]
            - totalBoostedRP: (250 + 500) * 1.2 = 900e18
            index = 0.02e18 + [10e18 SP / 900e18 RP]
                  = 0.02e18 + 1.111...111e16
                  = 0.031111e18
            both users had staked half their RP balances from t6-t16
         */

        uint256 totalRpStaked = user1Rp/2 + user2Rp/2;
        uint256 numOfNftsStaked = 2;                            // user2: 2nfts staked for t6-t16
        uint256 boostedAmount = (totalRpStaked * (numOfNftsStaked * pool.NFT_MULTIPLIER()) / pool.PRECISION_BASE());
        uint256 totalBoostedRp = totalRpStaked + boostedAmount;

        uint256 indexDelta = 10 ether * 1E18 / totalBoostedRp;
        uint256 expectedIndex = 0.02E18 + indexDelta;
        console.log("expectedIndex", expectedIndex);
        assertEq(expectedIndex, 31111111111111111); // 3.111e16
        
        // dynamic
        assertEq(distribution.index, expectedIndex);
        assertEq(distribution.totalEmitted, 15 ether);
        assertEq(distribution.lastUpdateTimeStamp, 16);
    }

    function testVault1Account0_T16() public {
        DataTypes.Distribution memory distribution = getDistribution(0);
        DataTypes.Vault memory vault = pool.getVault(vaultId1);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);
        
        /** T6 - T16
            stakedTokens: user1 1/2 + user 2 1/2
            stakedRp: user1 1/2 + user 2 1/2
            stakedNfts: 2
         */

        // cal. newly accrued rewards
        uint256 prevVaultIndex = 0.02e18;
        uint256 boostedBalance = (user1Rp/2 + user2Rp/2) * 120/100;    // user 2 stakes 2 nfts at t6-t16
        uint256 newlyAccRewards = calculateRewards(boostedBalance, distribution0_T16.index, prevVaultIndex, 1E18);
        // eval. rounding error
        uint256 newlyAccRewardsExpected = 10 ether;                   // ignores rounding 
        assertApproxEqAbs(newlyAccRewards, newlyAccRewardsExpected, 100);

        // newly accrued fees since last update: based on newlyAccRewards
        uint256 newlyAccCreatorFee = newlyAccRewards * 1000 / 10_000;
        uint256 newlyAccTotalNftFee = newlyAccRewards * 1000 / 10_000;         // 2 nfts staked frm t6-t16
        uint256 newlyAccRealmPointsFee = newlyAccRewards * 1000 / 10_000;
        
        // latest indices
        uint256 latestNftIndex = (newlyAccTotalNftFee / 2) + vault1Account0_T6.nftIndex;     // 2 nfts staked frm t6-t16
        uint256 latestRpIndex = (newlyAccRealmPointsFee * 1E18 / (user1Rp/2 + user2Rp/2)) + vault1Account0_T6.rpIndex;

        // check indices
        assertEq(vaultAccount.index, distribution.index); // must match distribution index
        assertEq(vaultAccount.nftIndex, latestNftIndex);
        assertEq(vaultAccount.rpIndex, latestRpIndex);    

        // calc. accumulated rewards
        uint256 totalAccRewards = newlyAccRewards + vault1Account0_T6.totalAccRewards;
        // calc. accumulated fees
        uint256 latestAccCreatorFee = newlyAccCreatorFee + vault1Account0_T6.accCreatorRewards;
        uint256 latestAccTotalNftFee = newlyAccTotalNftFee + vault1Account0_T6.accNftStakingRewards;
        uint256 latestAccRealmPointsFee = newlyAccRealmPointsFee + vault1Account0_T6.accRealmPointsRewards;

        // heck accumulated rewards + fees
        assertEq(vaultAccount.totalAccRewards, totalAccRewards);
        assertEq(vaultAccount.accCreatorRewards, latestAccCreatorFee); 
        assertEq(vaultAccount.accNftStakingRewards, latestAccTotalNftFee); 
        assertEq(vaultAccount.accRealmPointsRewards, latestAccRealmPointsFee); 

        // rewardsAccPerUnitStaked: for moca stakers
        uint256 latestAccRewardsLessOfFees = newlyAccRewards - newlyAccCreatorFee - newlyAccTotalNftFee - newlyAccRealmPointsFee;
        uint256 expectedRewardsAccPerUnitStaked = (latestAccRewardsLessOfFees * 1E18 / (user1Moca/2 + user2Moca/2)) + vault1Account0_T6.rewardsAccPerUnitStaked;

        // rewardsAccPerUnitStaked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked); 

        // totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

    function testUser1_ForVault1Account0_T16() public {

        DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId1, 0);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);

        //--- user 1 last updated at t1

        // Check indices match vault
        assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked);
        assertEq(userAccount.nftIndex, vaultAccount.nftIndex);
        assertEq(userAccount.rpIndex, vaultAccount.rpIndex);

        // Calculate expected rewards for user1's staked tokens
        uint256 latestAccStakingRewards = calculateRewards(user1Moca/2, vaultAccount.rewardsAccPerUnitStaked, user1Account0_T6.index, 1E18) + user1Account0_T6.accStakingRewards;      
        // Calculate expected rewards for nft staking
        uint256 latestAccNftStakingRewards = 0; // 0 nfts staked
        // Calculate expected rewards for rp staking
        uint256 latestAccRealmPointsRewards = calculateRewards(user1Rp/2, vaultAccount.rpIndex, user1Account0_T6.rpIndex, 1E18) + user1Account0_T6.accRealmPointsRewards;

        // Check accumulated rewards
        assertEq(userAccount.accStakingRewards, latestAccStakingRewards); 
        assertEq(userAccount.accNftStakingRewards, latestAccNftStakingRewards);
        assertEq(userAccount.accRealmPointsRewards, latestAccRealmPointsRewards);

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0);
        assertEq(userAccount.claimedNftRewards, 0);
        assertEq(userAccount.claimedRealmPointsRewards, 0);
        assertEq(userAccount.claimedCreatorRewards, 0);
        
        //--------------------------------
        
        // view fn: user1 gets their share of total rewards
        uint256 claimableRewards = pool.getClaimableRewards(user1, vaultId1, 0);
        
        uint256 expectedClaimableRewards = latestAccStakingRewards + latestAccNftStakingRewards + latestAccRealmPointsRewards;
        if (user1 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

        assertEq(claimableRewards, expectedClaimableRewards); 
    }

    function testUser2_ForVault1Account0_T16() public {
        DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId1, 0);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);

        //--- user2 last updated at t6: consider the emissions from t6-t16

        // Check indices match vault@t16
        assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked);
        assertEq(userAccount.nftIndex, vaultAccount.nftIndex);
        assertEq(userAccount.rpIndex, vaultAccount.rpIndex);

        // Calculate expected rewards for user1's staked tokens
        uint256 latestAccStakingRewards = calculateRewards(user2Moca/2, vaultAccount.rewardsAccPerUnitStaked, user2Account0_T6.index, 1E18) + user2Account0_T6.accStakingRewards;      
        // Calculate expected rewards for nft staking
        uint256 latestAccNftStakingRewards = ((vaultAccount.nftIndex - user2Account0_T6.nftIndex) * 2) + user2Account0_T6.accNftStakingRewards; // 2 nfts staked
        // Calculate expected rewards for rp staking
        uint256 latestAccRealmPointsRewards = calculateRewards(user2Rp/2, vaultAccount.rpIndex, user2Account0_T6.rpIndex, 1E18) + user2Account0_T6.accRealmPointsRewards;

        // Check accumulated rewards
        assertEq(userAccount.accStakingRewards, latestAccStakingRewards); 
        assertEq(userAccount.accNftStakingRewards, latestAccNftStakingRewards);
        assertEq(userAccount.accRealmPointsRewards, latestAccRealmPointsRewards);

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0);
        assertEq(userAccount.claimedNftRewards, 0);
        assertEq(userAccount.claimedRealmPointsRewards, 0);
        assertEq(userAccount.claimedCreatorRewards, 0);
        
        //--------------------------------
        
        // view fn: user2 gets their share of total rewards
        uint256 claimableRewards = pool.getClaimableRewards(user2, vaultId1, 0);
        
        uint256 expectedClaimableRewards = latestAccStakingRewards + latestAccNftStakingRewards + latestAccRealmPointsRewards;
        if (user2 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

        assertEq(claimableRewards, expectedClaimableRewards); 
    }

    // ---------------- distribution 1 ----------------
    
    // distribution 1 not yet started
    function testDistribution1_T16() public {
        // Check all Distribution struct fields
        DataTypes.Distribution memory distribution = getDistribution(1);
        
        // static
        assertEq(distribution.distributionId, 1);
        assertEq(distribution.TOKEN_PRECISION, 1e18); 
        assertEq(distribution.endTime, 100 + 21);
        assertEq(distribution.startTime, 21);
        assertEq(distribution.emissionPerSecond, 1 ether);
        assertEq(distribution.manuallyEnded, 0);        

        // dynamic
        assertEq(distribution.index, 0);
        assertEq(distribution.totalEmitted, 0);
        assertEq(distribution.lastUpdateTimeStamp, 21);
    }

    function testVault1Account1_T16() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        DataTypes.Vault memory vault = pool.getVault(vaultId1);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);
        
        // Check indices match distribution
        assertEq(vaultAccount.index, distribution.index);
        assertEq(vaultAccount.nftIndex, 0);
        assertEq(vaultAccount.rpIndex, 0);

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, 0);
        assertEq(vaultAccount.accCreatorRewards, 0);
        assertEq(vaultAccount.accNftStakingRewards, 0); 
        assertEq(vaultAccount.accRealmPointsRewards, 0);

        // Check rewards per unit staked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, 0);

        // Check claimed rewards
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

    function testUser1_ForVault1Account1_T16() public {
        DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId1, 1);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);
        
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
    }

    function testUser2_ForVault1Account1_T16() public {
        DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId1, 1);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);
        
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
    }    

    // ---------------- others ----------------

    function testUpdateCreationNfts(uint256 newAmount) public {
        // operator updates CREATION_NFTS_REQUIRED
        vm.startPrank(operator);
            vm.expectEmit(true, true, false, false);
            emit CreationNftRequiredUpdated(pool.CREATION_NFTS_REQUIRED(), newAmount);
            pool.updateCreationNfts(newAmount);
        vm.stopPrank();
    
        assertEq(pool.CREATION_NFTS_REQUIRED(), newAmount);
    }

}

//note: creation nfts updated at t21 | distribution_1 starts at t21
abstract contract StateT21_CreationNftsUpdated is StateT16_BothUsersStakeAgain {

    // for reference
    DataTypes.Distribution distribution0_T21;
    DataTypes.Distribution distribution1_T21;

    DataTypes.VaultAccount vault1Account0_T21;
    DataTypes.VaultAccount vault1Account1_T21;

    DataTypes.UserAccount user1Account0_T21;
    DataTypes.UserAccount user2Account0_T21;

    function setUp() public virtual override {
        super.setUp();

        // T16   
        vm.warp(21);
    
        // operator updates CREATION_NFTS_REQUIRED
        vm.startPrank(operator);
            pool.updateCreationNfts(1);
        vm.stopPrank();

        // save state
        distribution0_T21 = getDistribution(0);
        distribution1_T21 = getDistribution(1);
        vault1Account0_T21 = getVaultAccount(vaultId1, 0);
        vault1Account1_T21 = getVaultAccount(vaultId1, 1);
        user1Account0_T21 = getUserAccount(user1, vaultId1, 0);
        user2Account0_T21 = getUserAccount(user2, vaultId1, 0);
    }
}

contract StateT21_CreationNftsUpdatedTest is StateT21_CreationNftsUpdated {
    
    /**
     NOTE: distribution 1 started
     but no state update done for vaults, users, distributions

     todo: view fns calculate the correct pending rewards
     */
    
    function testUser2CannotReuseCreationNfts() public {
        vm.startPrank(user2);
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = user2NftsArray[0];  

            vm.expectRevert(abi.encodeWithSelector(NftRegistry.NftIsStaked.selector));
            pool.createVault(tokenIds, 1000, 500, 500);
        vm.stopPrank();
    }

    // can create vault w/ update limit
    function testUser2CreatesVault() public {
        bytes32 vaultId2 = generateVaultId(block.number - 1, user2);

        // user2 creates vault
        vm.startPrank(user2);
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = user2NftsArray[4];    //5th nft
            uint256 nftFeeFactor = 1000;
            uint256 creatorFeeFactor = 500;
            uint256 realmPointsFeeFactor = 500;
            
            vm.expectEmit(true, true, true, true);
            emit VaultCreated(vaultId2, user2, nftFeeFactor, creatorFeeFactor, realmPointsFeeFactor);
            pool.createVault(tokenIds, nftFeeFactor, creatorFeeFactor, realmPointsFeeFactor);
        vm.stopPrank();
        // check vault
        DataTypes.Vault memory vault = pool.getVault(vaultId2);
        
        // creator
        assertEq(vault.creator, user2);
        
        // creation nfts
        assertEq(vault.creationTokenIds.length, 1);
        assertEq(vault.creationTokenIds[0], user2NftsArray[4]);
        
        // timing
        assertEq(vault.startTime, 21);
        assertEq(vault.endTime, 0);
        assertEq(vault.removed, 0);
        
        // fees
        assertEq(vault.nftFeeFactor, nftFeeFactor);
        assertEq(vault.creatorFeeFactor, creatorFeeFactor);
        assertEq(vault.realmPointsFeeFactor, realmPointsFeeFactor);
        
        // staked assets (should be 0 initially)
        assertEq(vault.stakedNfts, 0);
        assertEq(vault.stakedTokens, 0); 
        assertEq(vault.stakedRealmPoints, 0);
        
        // boost factors (should start at base precision)
        assertEq(vault.totalBoostFactor, pool.PRECISION_BASE());
        assertEq(vault.boostedRealmPoints, 0);
        assertEq(vault.boostedStakedTokens, 0);
    }
}

//note: creation nfts updated at t21 | distribution_1 starts at t21
abstract contract StateT26_User2CreatesVault2 is StateT21_CreationNftsUpdated {

    bytes32 vaultId2;

    function setUp() public virtual override {
        super.setUp();

        vm.warp(26);

        // user2 creates vault
        vm.startPrank(user2);
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = user2NftsArray[4];    //5th nft
            uint256 nftFeeFactor = 1000;
            uint256 creatorFeeFactor = 500;
            uint256 realmPointsFeeFactor = 500;

            pool.createVault(tokenIds, nftFeeFactor, creatorFeeFactor, realmPointsFeeFactor);
        vm.stopPrank();       

        vaultId2 = generateVaultId(block.number - 1, user2);
    }
}

contract StateT26_User2CreatesVault2Test is StateT26_User2CreatesVault2 {

    /** 
        creating a vault does not update state of existing distributions, vaults or users.
        so all state data related to these entities should be the same as in StateT16

        for sanity, we check that state is stale.
     */
    
    // ---------------- stale checks: should be as per T16 ----------------
        function testUser1_T26() public {
            DataTypes.User memory user = pool.getUser(user1, vaultId1);

            // nfts        
            assertEq(user.tokenIds.length, 0);

            // tokens
            assertEq(user.stakedTokens, user1Moca);

            // realm points
            assertEq(user.stakedRealmPoints, user1Rp);
        }

        function testUser2_T26() public {
            DataTypes.User memory user = pool.getUser(user2, vaultId1);

            // nfts        
            assertEq(user.tokenIds.length, 4);
            assertEq(user.tokenIds[0], user2NftsArray[0]);
            assertEq(user.tokenIds[1], user2NftsArray[1]); 
            assertEq(user.tokenIds[2], user2NftsArray[2]);
            assertEq(user.tokenIds[3], user2NftsArray[3]);

            // tokens
            assertEq(user.stakedTokens, user2Moca);

            // realm points
            assertEq(user.stakedRealmPoints, user2Rp);
        }

        // ---------------- distribution 0 ----------------

        function testDistribution0_T26() public {

            DataTypes.Distribution memory distribution = getDistribution(0);

            // static
            assertEq(distribution.distributionId, 0);
            assertEq(distribution.TOKEN_PRECISION, 1e18); 
            assertEq(distribution.endTime, 0);
            assertEq(distribution.startTime, 1);
            assertEq(distribution.emissionPerSecond, 1 ether);
            assertEq(distribution.manuallyEnded, 0);        
            
            /** index calc:
                - prev. index: 0.02e18 [t6]
                - totalEmitted: 10e18 SP
                - totalRpStaked: (250 + 500) [t6-t16]
                - totalBoostFactor: 1000 * 2 / PRECISION_BASE = 20% [20/100]
                - totalBoostedRP: (250 + 500) * 1.2 = 900e18
                index = 0.02e18 + [10e18 SP / 900e18 RP]
                    = 0.02e18 + 1.111...111e16
                    = 0.031111e18
                both users had staked half their RP balances from t6-t16
            */

            uint256 totalRpStaked = user1Rp/2 + user2Rp/2;
            uint256 numOfNftsStaked = 2;                            // user2: 2nfts staked for t6-t16
            uint256 boostedAmount = (totalRpStaked * (numOfNftsStaked * pool.NFT_MULTIPLIER()) / pool.PRECISION_BASE());
            uint256 totalBoostedRp = totalRpStaked + boostedAmount;

            uint256 indexDelta = 10 ether * 1E18 / totalBoostedRp;
            uint256 expectedIndex = 0.02E18 + indexDelta;
            console.log("expectedIndex", expectedIndex);
            assertEq(expectedIndex, 31111111111111111); // 3.111e16
            
            // dynamic
            assertEq(distribution.index, expectedIndex);
            assertEq(distribution.totalEmitted, 15 ether);
            assertEq(distribution.lastUpdateTimeStamp, 16);
        }

        function testVault1Account0_T26() public {
            DataTypes.Distribution memory distribution = getDistribution(0);
            DataTypes.Vault memory vault = pool.getVault(vaultId1);

            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);
            
            /** T6 - T16
                stakedTokens: user1 1/2 + user 2 1/2
                stakedRp: user1 1/2 + user 2 1/2
                stakedNfts: 2
            */

            // cal. newly accrued rewards
            uint256 prevVaultIndex = 0.02e18;
            uint256 boostedBalance = (user1Rp/2 + user2Rp/2) * 120/100;    // user 2 stakes 2 nfts at t6-t16
            uint256 newlyAccRewards = calculateRewards(boostedBalance, distribution0_T16.index, prevVaultIndex, 1E18);
            // eval. rounding error
            uint256 newlyAccRewardsExpected = 10 ether;                   // ignores rounding 
            assertApproxEqAbs(newlyAccRewards, newlyAccRewardsExpected, 100);

            // newly accrued fees since last update: based on newlyAccRewards
            uint256 newlyAccCreatorFee = newlyAccRewards * 1000 / 10_000;
            uint256 newlyAccTotalNftFee = newlyAccRewards * 1000 / 10_000;         // 2 nfts staked frm t6-t16
            uint256 newlyAccRealmPointsFee = newlyAccRewards * 1000 / 10_000;
            
            // latest indices
            uint256 latestNftIndex = (newlyAccTotalNftFee / 2) + vault1Account0_T6.nftIndex;     // 2 nfts staked frm t6-t16
            uint256 latestRpIndex = (newlyAccRealmPointsFee * 1E18 / (user1Rp/2 + user2Rp/2)) + vault1Account0_T6.rpIndex;

            // check indices
            assertEq(vaultAccount.index, distribution.index); // must match distribution index
            assertEq(vaultAccount.nftIndex, latestNftIndex);
            assertEq(vaultAccount.rpIndex, latestRpIndex);    

            // calc. accumulated rewards
            uint256 totalAccRewards = newlyAccRewards + vault1Account0_T6.totalAccRewards;
            // calc. accumulated fees
            uint256 latestAccCreatorFee = newlyAccCreatorFee + vault1Account0_T6.accCreatorRewards;
            uint256 latestAccTotalNftFee = newlyAccTotalNftFee + vault1Account0_T6.accNftStakingRewards;
            uint256 latestAccRealmPointsFee = newlyAccRealmPointsFee + vault1Account0_T6.accRealmPointsRewards;

            // heck accumulated rewards + fees
            assertEq(vaultAccount.totalAccRewards, totalAccRewards);
            assertEq(vaultAccount.accCreatorRewards, latestAccCreatorFee); 
            assertEq(vaultAccount.accNftStakingRewards, latestAccTotalNftFee); 
            assertEq(vaultAccount.accRealmPointsRewards, latestAccRealmPointsFee); 

            // rewardsAccPerUnitStaked: for moca stakers
            uint256 latestAccRewardsLessOfFees = newlyAccRewards - newlyAccCreatorFee - newlyAccTotalNftFee - newlyAccRealmPointsFee;
            uint256 expectedRewardsAccPerUnitStaked = (latestAccRewardsLessOfFees * 1E18 / (user1Moca/2 + user2Moca/2)) + vault1Account0_T6.rewardsAccPerUnitStaked;

            // rewardsAccPerUnitStaked
            assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked); 

            // totalClaimedRewards
            assertEq(vaultAccount.totalClaimedRewards, 0);
        }
        
        function testUser1_ForVault1Account0_T26() public {

            DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId1, 0);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);

            //--- user 1 last updated at t1

            // Check indices match vault
            assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked);
            assertEq(userAccount.nftIndex, vaultAccount.nftIndex);
            assertEq(userAccount.rpIndex, vaultAccount.rpIndex);

            // Calculate expected rewards for user1's staked tokens
            uint256 latestAccStakingRewards = calculateRewards(user1Moca/2, vaultAccount.rewardsAccPerUnitStaked, user1Account0_T6.index, 1E18) + user1Account0_T6.accStakingRewards;      
            // Calculate expected rewards for nft staking
            uint256 latestAccNftStakingRewards = 0; // 0 nfts staked
            // Calculate expected rewards for rp staking
            uint256 latestAccRealmPointsRewards = calculateRewards(user1Rp/2, vaultAccount.rpIndex, user1Account0_T6.rpIndex, 1E18) + user1Account0_T6.accRealmPointsRewards;

            // Check accumulated rewards
            assertEq(userAccount.accStakingRewards, latestAccStakingRewards); 
            assertEq(userAccount.accNftStakingRewards, latestAccNftStakingRewards);
            assertEq(userAccount.accRealmPointsRewards, latestAccRealmPointsRewards);

            // Check claimed rewards
            assertEq(userAccount.claimedStakingRewards, 0);
            assertEq(userAccount.claimedNftRewards, 0);
            assertEq(userAccount.claimedRealmPointsRewards, 0);
            assertEq(userAccount.claimedCreatorRewards, 0);
            
            //--------------------------------
            /* note: update expectedClaimableRewards to include pending rewards

                // view fn: user1 gets their share of total rewards
                uint256 claimableRewards = pool.getClaimableRewards(user1, vaultId1, 0);
                
                uint256 expectedClaimableRewards = latestAccStakingRewards + latestAccNftStakingRewards + latestAccRealmPointsRewards;
                if (user1 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

                // book pending
                expectedClaimableRewards += 

                assertEq(claimableRewards, expectedClaimableRewards); 
            */
        }

        function testUser2_ForVault1Account0_T26() public {
            DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId1, 0);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);

            //--- user2 last updated at t6: consider the emissions from t6-t16

            // Check indices match vault@t16
            assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked);
            assertEq(userAccount.nftIndex, vaultAccount.nftIndex);
            assertEq(userAccount.rpIndex, vaultAccount.rpIndex);

            // Calculate expected rewards for user1's staked tokens
            uint256 latestAccStakingRewards = calculateRewards(user2Moca/2, vaultAccount.rewardsAccPerUnitStaked, user2Account0_T6.index, 1E18) + user2Account0_T6.accStakingRewards;      
            // Calculate expected rewards for nft staking
            uint256 latestAccNftStakingRewards = ((vaultAccount.nftIndex - user2Account0_T6.nftIndex) * 2) + user2Account0_T6.accNftStakingRewards; // 2 nfts staked
            // Calculate expected rewards for rp staking
            uint256 latestAccRealmPointsRewards = calculateRewards(user2Rp/2, vaultAccount.rpIndex, user2Account0_T6.rpIndex, 1E18) + user2Account0_T6.accRealmPointsRewards;

            // Check accumulated rewards
            assertEq(userAccount.accStakingRewards, latestAccStakingRewards); 
            assertEq(userAccount.accNftStakingRewards, latestAccNftStakingRewards);
            assertEq(userAccount.accRealmPointsRewards, latestAccRealmPointsRewards);

            // Check claimed rewards
            assertEq(userAccount.claimedStakingRewards, 0);
            assertEq(userAccount.claimedNftRewards, 0);
            assertEq(userAccount.claimedRealmPointsRewards, 0);
            assertEq(userAccount.claimedCreatorRewards, 0);
            
            //--------------------------------
            /* note: update expectedClaimableRewards to include pending rewards
            
            // view fn: user2 gets their share of total rewards
            uint256 claimableRewards = pool.getClaimableRewards(user2, vaultId1, 0);
            
            uint256 expectedClaimableRewards = latestAccStakingRewards + latestAccNftStakingRewards + latestAccRealmPointsRewards;
            if (user2 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

                assertEq(claimableRewards, expectedClaimableRewards); 
            */
        }

        // ---------------- distribution 1 ----------------
        
        // distribution 1 started@T21: state not updated
        function testDistribution1_T16() public {
            // Check all Distribution struct fields
            DataTypes.Distribution memory distribution = getDistribution(1);
            
            // static
            assertEq(distribution.distributionId, 1);
            assertEq(distribution.TOKEN_PRECISION, 1e18); 
            assertEq(distribution.endTime, 100 + 21);
            assertEq(distribution.startTime, 21);
            assertEq(distribution.emissionPerSecond, 1 ether);
            assertEq(distribution.manuallyEnded, 0);        

            // dynamic
            assertEq(distribution.index, 0);
            assertEq(distribution.totalEmitted, 0);
            assertEq(distribution.lastUpdateTimeStamp, 21);
        }

        function testVault1Account1_T16() public {
            DataTypes.Distribution memory distribution = getDistribution(1);
            DataTypes.Vault memory vault = pool.getVault(vaultId1);

            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);
            
            // Check indices match distribution
            assertEq(vaultAccount.index, distribution.index);
            assertEq(vaultAccount.nftIndex, 0);
            assertEq(vaultAccount.rpIndex, 0);

            // Check accumulated rewards
            assertEq(vaultAccount.totalAccRewards, 0);
            assertEq(vaultAccount.accCreatorRewards, 0);
            assertEq(vaultAccount.accNftStakingRewards, 0); 
            assertEq(vaultAccount.accRealmPointsRewards, 0);

            // Check rewards per unit staked
            assertEq(vaultAccount.rewardsAccPerUnitStaked, 0);

            // Check claimed rewards
            assertEq(vaultAccount.totalClaimedRewards, 0);
        }

        function testUser1_ForVault1Account1_T16() public {
            DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId1, 1);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);
            
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
        }

        function testUser2_ForVault1Account1_T16() public {
            DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId1, 1);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);
            
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
        }   

    // ---------------- stale checks: ended -------------------------------- //

    // ---------- vault2 checks: vault struct populated; accounts empty ---------

    //note: pool.totalCreationNfts should be updated
    function testPool_T26() public {
        DataTypes.Vault memory vault1 = pool.getVault(vaultId1);
        DataTypes.Vault memory vault2 = pool.getVault(vaultId2);

        // Check total creation NFTs
        assertEq(pool.totalCreationNfts(), 6);
        assertEq(pool.totalCreationNfts(), vault1.creationTokenIds.length + vault2.creationTokenIds.length);

        // Check total staked assets
        assertEq(pool.totalStakedNfts(), 4); // user2's 4 staked NFTs
        assertEq(pool.totalStakedTokens(), user1Moca + user2Moca);
        assertEq(pool.totalStakedRealmPoints(), user1Rp + user2Rp);

        // Check boosted balances
        uint256 expectedBoostFactor = 10_000 + (4 * nftMultiplier); // Base + 4 NFTs from user2
        uint256 expectedBoostedRealmPoints = ((user1Rp + user2Rp) * expectedBoostFactor) / 10_000;
        uint256 expectedBoostedStakedTokens = ((user1Moca + user2Moca) * expectedBoostFactor) / 10_000;

        assertEq(pool.totalBoostedRealmPoints(), expectedBoostedRealmPoints);
        assertEq(pool.totalBoostedStakedTokens(), expectedBoostedStakedTokens);
    }

    function testVault2_T26() public {
        DataTypes.Vault memory vault = pool.getVault(vaultId2);
        
        // Base vault data
        assertEq(vault.creator, user2);
        // Verify creation NFTs
        assertEq(vault.creationTokenIds.length, 1);
        assertEq(vault.creationTokenIds[0], user2NftsArray[4]);

        assertEq(vault.startTime, 26);
        assertEq(vault.endTime, 0);
        assertEq(vault.removed, 0);
        
        // Verify fees
        assertEq(vault.nftFeeFactor, 1000);
        assertEq(vault.creatorFeeFactor, 500);
        assertEq(vault.realmPointsFeeFactor, 500);
        
        // Verify staked assets
        assertEq(vault.stakedTokens, 0);
        assertEq(vault.stakedNfts, 0);
        assertEq(vault.stakedRealmPoints, 0);

        // Verify boosted balances
        assertEq(vault.totalBoostFactor, pool.PRECISION_BASE());
        assertEq(vault.boostedRealmPoints, 0);
        assertEq(vault.boostedStakedTokens, 0);
    }

    function testVault2Account0_T26() public {
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 0);
        
        // Check indices
        assertEq(vaultAccount.index, 0);
        assertEq(vaultAccount.nftIndex, 0);
        assertEq(vaultAccount.rpIndex, 0);

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, 0);
        assertEq(vaultAccount.accCreatorRewards, 0);
        assertEq(vaultAccount.accNftStakingRewards, 0);
        assertEq(vaultAccount.accRealmPointsRewards, 0);

        // Check per unit rewards and total claimed
        assertEq(vaultAccount.rewardsAccPerUnitStaked, 0);
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

    function testVault2Account1_T26() public {
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 1);
        
        // Check indices
        assertEq(vaultAccount.index, 0);
        assertEq(vaultAccount.nftIndex, 0);
        assertEq(vaultAccount.rpIndex, 0);

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, 0);
        assertEq(vaultAccount.accCreatorRewards, 0);
        assertEq(vaultAccount.accNftStakingRewards, 0);
        assertEq(vaultAccount.accRealmPointsRewards, 0);

        // Check per unit rewards and total claimed
        assertEq(vaultAccount.rewardsAccPerUnitStaked, 0);
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

    // next state
    function testUser2MigrateRp() public {
        
        // get initial values
        uint256 poolBoostedRpBefore = pool.totalBoostedRealmPoints();
        uint256 poolTotalRpBefore = pool.totalStakedRealmPoints();
        DataTypes.Vault memory vault1Before = pool.getVault(vaultId1);
        DataTypes.Vault memory vault2Before = pool.getVault(vaultId2);
        DataTypes.User memory user2VaultOneBefore = pool.getUser(user2, vaultId1);
        DataTypes.User memory user2VaultTwoBefore = pool.getUser(user2, vaultId2);

        // user2 migrates half their RP from vault1 to vault2
        vm.startPrank(user2);
            uint256 amount = user2Rp/2;
            // check event
            vm.expectEmit(true, true, true, true);
            emit RealmPointsMigrated(user2, vaultId1, vaultId2, amount);
            pool.migrateRealmPoints(vaultId1, vaultId2, amount);
        vm.stopPrank();
        
        // --------- VAULT1 CHECKS: before & after migration ---------

        // check vault1 (old vault) balances
        DataTypes.Vault memory vault1After = pool.getVault(vaultId1);
        
        // Base RP checks for vault1
        assertEq(vault1After.stakedRealmPoints, vault1Before.stakedRealmPoints - amount, "Vault1 base RP not reduced correctly");
        // Boosted RP checks for vault1
        uint256 expectedVault1BoostFactor = pool.PRECISION_BASE() + (vault1After.stakedNfts * pool.NFT_MULTIPLIER());
        uint256 expectedVault1BoostedRp = (vault1After.stakedRealmPoints * expectedVault1BoostFactor) / pool.PRECISION_BASE();
        assertEq(vault1After.boostedRealmPoints, expectedVault1BoostedRp, "Vault1 boosted RP not reduced correctly");

        // --------- VAULT2 CHECKS: before & after migration ---------

        // check vault2 (new vault) balances
        DataTypes.Vault memory vault2After = pool.getVault(vaultId2);
        
        // Base RP checks for vault2
        assertEq(vault2After.stakedRealmPoints, vault2Before.stakedRealmPoints + amount, "Vault2 base RP not increased correctly");
        // Boosted RP checks for vault2
        uint256 expectedVault2BoostFactor = pool.PRECISION_BASE() + (vault2After.stakedNfts * pool.NFT_MULTIPLIER());
        uint256 expectedVault2BoostedRp = (vault2After.stakedRealmPoints * expectedVault2BoostFactor) / pool.PRECISION_BASE();
        assertEq(vault2After.boostedRealmPoints, expectedVault2BoostedRp, "Vault2 boosted RP not increased correctly");

        // --------- POOL CHECKS: before & after migration ---------

        // check pool totals
        assertEq(pool.totalStakedRealmPoints(), poolTotalRpBefore, "Pool total RP should not change");
        assertEq(pool.totalBoostedRealmPoints(), expectedVault1BoostedRp + expectedVault2BoostedRp, "Pool total boosted RP incorrect");

        // --------- USER-VAULT BALANCES CHECKS: before & after migration ---------

        // check user balances for vault1
        DataTypes.User memory user2VaultOneAfter = pool.getUser(user2, vaultId1);
        assertEq(user2VaultOneAfter.stakedRealmPoints, user2VaultOneBefore.stakedRealmPoints - amount, "User2 vault1 RP not reduced correctly");

        // check user balances for vault2
        DataTypes.User memory user2VaultTwoAfter = pool.getUser(user2, vaultId2);
        assertEq(user2VaultTwoAfter.stakedRealmPoints, user2VaultTwoBefore.stakedRealmPoints + amount, "User2 vault2 RP not increased correctly");


        // ----- MISC: OTHER CHECKS -----
        
        // Other vault1 checks
        assertEq(vault1After.stakedNfts, vault1Before.stakedNfts, "Vault1 NFTs should not change");
        assertEq(vault1After.stakedTokens, vault1Before.stakedTokens, "Vault1 tokens should not change");
        assertEq(vault1After.totalBoostFactor, expectedVault1BoostFactor, "Vault1 boost factor incorrect");
        assertEq(vault1After.boostedStakedTokens, (vault1After.stakedTokens * expectedVault1BoostFactor) / pool.PRECISION_BASE(), "Vault1 boosted tokens incorrect");

        // Other vault2 checks
        assertEq(vault2After.stakedNfts, vault2Before.stakedNfts, "Vault2 NFTs should not change");
        assertEq(vault2After.stakedTokens, vault2Before.stakedTokens, "Vault2 tokens should not change");
        assertEq(vault2After.totalBoostFactor, expectedVault2BoostFactor, "Vault2 boost factor incorrect");
        assertEq(vault2After.boostedStakedTokens, (vault2After.stakedTokens * expectedVault2BoostFactor) / pool.PRECISION_BASE(), "Vault2 boosted tokens incorrect");
    }
}

//note: user2 migrates half his RP to vault2
abstract contract StateT31_User2MigrateRpToVault2 is StateT26_User2CreatesVault2 {

    // for reference
    DataTypes.Vault vault1_T31; 
    DataTypes.Vault vault2_T31;

    DataTypes.Distribution distribution0_T31;
    DataTypes.Distribution distribution1_T31;
    //vault1
    DataTypes.VaultAccount vault1Account0_T31;
    DataTypes.VaultAccount vault1Account1_T31;
    //vault2
    DataTypes.VaultAccount vault2Account0_T31;
    DataTypes.VaultAccount vault2Account1_T31;
    //user1+vault1
    DataTypes.UserAccount user1Account0_T31;
    DataTypes.UserAccount user1Account1_T31;
    //user2+vault1
    DataTypes.UserAccount user2Account0_T31;
    DataTypes.UserAccount user2Account1_T31;
    //user1+vault2
    DataTypes.UserAccount user1Vault2Account0_T31;
    DataTypes.UserAccount user1Vault2Account1_T31;
    //user2+vault2
    DataTypes.UserAccount user2Vault2Account0_T31;
    DataTypes.UserAccount user2Vault2Account1_T31;

    function setUp() public virtual override {
        super.setUp();

        vm.warp(31);

        // user2 migrates half of assets to vault2 [migrateRp]
        vm.startPrank(user2);
            pool.migrateRealmPoints(vaultId1, vaultId2, user2Rp/2);
        vm.stopPrank();

        // save state
        vault1_T31 = pool.getVault(vaultId1);
        vault2_T31 = pool.getVault(vaultId2);
        
        distribution0_T31 = getDistribution(0);
        distribution1_T31 = getDistribution(1);
        vault1Account0_T31 = getVaultAccount(vaultId1, 0);
        vault1Account1_T31 = getVaultAccount(vaultId1, 1);  
        vault2Account0_T31 = getVaultAccount(vaultId2, 0);
        vault2Account1_T31 = getVaultAccount(vaultId2, 1);
        user1Account0_T31 = getUserAccount(user1, vaultId1, 0);
        user1Account1_T31 = getUserAccount(user1, vaultId1, 1);
        user2Account0_T31 = getUserAccount(user2, vaultId1, 0);
        user2Account1_T31 = getUserAccount(user2, vaultId1, 1);
        user1Vault2Account0_T31 = getUserAccount(user1, vaultId2, 0);
        user1Vault2Account1_T31 = getUserAccount(user1, vaultId2, 1);
        user2Vault2Account0_T31 = getUserAccount(user2, vaultId2, 0);
        user2Vault2Account1_T31 = getUserAccount(user2, vaultId2, 1);
    }   
}

contract StateT31_User2MigrateRpToVault2Test is StateT31_User2MigrateRpToVault2 {

    /**
        note: test stuff related to migrating rp

        migrateRP by user2 frm vault1 to vault2.
         vault1 accounts updated.
         vault2 accounts updated.
         user2 accounts updated. [check: T16-T31]
         user1 NOT updated - stale. [t16 was lastupdate]

        vault2 created at T26, has accounts with both active distributions.
         but accrues no rewards of any kind to date, since nothing staked. 
         its vaultAccounts and related userAccounts should primarily be 0.
     */

    // ---------------- base assets ----------------

    //pool & vaults should be updated
    function testPool_T31() public {
        DataTypes.Vault memory vault1 = pool.getVault(vaultId1);
        DataTypes.Vault memory vault2 = pool.getVault(vaultId2);

        // Check total creation NFTs - unchanged
        assertEq(pool.totalCreationNfts(), 5 + 1);
        assertEq(pool.totalCreationNfts(), vault1.creationTokenIds.length + vault2.creationTokenIds.length);

        // Check total staked assets - unchanged since migration just moves RP between vaults
        assertEq(pool.totalStakedNfts(), 4); // user2's 4 NFTs staked in vault1
        assertEq(pool.totalStakedTokens(), user1Moca + user2Moca);

        // RP totals
        assertEq(pool.totalStakedRealmPoints(), user1Rp + user2Rp);
        assertEq(pool.totalStakedRealmPoints(), vault1.stakedRealmPoints + vault2.stakedRealmPoints);
        
        // Check vault1 balances
        assertEq(vault1.stakedRealmPoints, user1Rp + user2Rp/2); // Half of user2's RP moved out
        assertEq(vault1.stakedTokens, user1Moca + user2Moca); // Tokens unchanged
        assertEq(vault1.stakedNfts, 4); // user2's 4 NFTs

        // Check vault2 balances
        assertEq(vault2.stakedRealmPoints, user2Rp/2); // Half of user2's RP moved in
        assertEq(vault2.stakedTokens, 0);  // no tokens moved
        assertEq(vault2.stakedNfts, 0);    // no NFTs staked yet

        // Check boosted balances
        uint256 vault1BoostFactor = 10_000 + (vault1.stakedNfts * pool.NFT_MULTIPLIER());
        uint256 vault2BoostFactor = 10_000 + (vault2.stakedNfts * pool.NFT_MULTIPLIER());

        uint256 vault1BoostedRp = (vault1.stakedRealmPoints * vault1BoostFactor) / 10_000;
        uint256 vault2BoostedRp = (vault2.stakedRealmPoints * vault2BoostFactor) / 10_000;
        uint256 vault1BoostedTokens = (vault1.stakedTokens * vault1BoostFactor) / 10_000;

        assertEq(pool.totalBoostedRealmPoints(), vault1BoostedRp + vault2BoostedRp);
        assertEq(pool.totalBoostedStakedTokens(), vault1BoostedTokens); // Only vault1 has tokens
    }

    function testVault1_T31() public {
        DataTypes.Vault memory vault1 = pool.getVault(vaultId1);
        
        // Check base balances
        assertEq(vault1.stakedRealmPoints, user1Rp + user2Rp/2);
        assertEq(vault1.stakedTokens, user1Moca + user2Moca);
        assertEq(vault1.stakedNfts, 4);

        // Check boosted values
        uint256 boostFactor = 10_000 + (vault1.stakedNfts * pool.NFT_MULTIPLIER());
        uint256 expectedBoostedRp = (vault1.stakedRealmPoints * boostFactor) / 10_000;
        uint256 expectedBoostedTokens = (vault1.stakedTokens * boostFactor) / 10_000;
        
        assertEq(vault1.totalBoostFactor, boostFactor);
        assertEq(vault1.boostedRealmPoints, expectedBoostedRp);
        assertEq(vault1.boostedStakedTokens, expectedBoostedTokens);
    }

    function testVault2_T31() public {
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

    // ---------------- distribution 0 ----------------

    function testDistribution0_T31() public {

        DataTypes.Distribution memory distribution = getDistribution(0);

        // static
        assertEq(distribution.distributionId, 0);
        assertEq(distribution.TOKEN_PRECISION, 1e18); 
        assertEq(distribution.endTime, 0);
        assertEq(distribution.startTime, 1);
        assertEq(distribution.emissionPerSecond, 1 ether);
        assertEq(distribution.manuallyEnded, 0);        
        
        /** index calc: t16 - t30 [delta: 15]
            - prev. index: 3.111e16 [t16: 31111111111111111]
            - totalEmittedSinceLastUpdate: 15e18 SP
            - totalRpStaked: (500 + 1000)
            - totalBoostFactor: 1000 * 4 / PRECISION_BASE = 40% [40/100]
            - totalBoostedRP: (500 + 1000) * 1.4 = 2100e18
            index = 3.111e16 + [15e18 SP / 2100 RP]
                  = 3.111e16 + 0.714285e16
                  ~ 3.8253968253968253e16
         */

        uint256 totalRpStaked = user1Rp + user2Rp;
        uint256 numOfNftsStaked = 4;                            // user2: 4nfts staked for t16-t30
        uint256 boostedAmount = (totalRpStaked * (numOfNftsStaked * pool.NFT_MULTIPLIER()) / pool.PRECISION_BASE());
        uint256 totalBoostedRp = totalRpStaked + boostedAmount;

        uint256 indexDelta = 15 ether * 1E18 / totalBoostedRp;
        uint256 expectedIndex = distribution0_T16.index + indexDelta;
        console.log("expectedIndex", expectedIndex);
        assertEq(expectedIndex, 3.8253968253968253e16);
        
        // dynamic
        assertEq(distribution.index, expectedIndex);
        assertEq(distribution.totalEmitted, distribution0_T16.totalEmitted + 15 ether);
        assertEq(distribution.lastUpdateTimeStamp, 31);
    }

    function testVault1Account0_T31() public {
        DataTypes.Distribution memory distribution = getDistribution(0);
        DataTypes.Vault memory vault = pool.getVault(vaultId1);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);
        
        /** T16 - T31
            stakedTokens: user1 + user 2 
            stakedRp: user1 + user 2 
            stakedNfts: 4
         */
          
        // vault assets 
        uint256 stakedRp = user1Rp + user2Rp;  
        uint256 stakedTokens = user1Moca + user2Moca;
        uint256 stakedNfts = 4;
        uint256 prevVaultIndex = vault1Account0_T16.index;

        // calc. newly accrued rewards       
        uint256 boostFactor = pool.PRECISION_BASE() + (stakedNfts * pool.NFT_MULTIPLIER());
        uint256 boostedRpBalance = stakedRp * boostFactor / pool.PRECISION_BASE();
        uint256 newlyAccRewards = calculateRewards(boostedRpBalance, distribution0_T31.index, prevVaultIndex, 1E18);
        // eval. rounding error
        uint256 newlyAccRewardsExpected = 15 ether;                   // ignores rounding 
        assertApproxEqAbs(newlyAccRewards, newlyAccRewardsExpected, 1800);

        // newly accrued fees since last update: based on newlyAccRewards
        uint256 newlyAccCreatorFee = newlyAccRewards * 1000 / 10_000;
        uint256 newlyAccTotalNftFee = newlyAccRewards * 1000 / 10_000;         
        uint256 newlyAccRealmPointsFee = newlyAccRewards * 1000 / 10_000;
        
        // latest indices
        uint256 latestNftIndex = (newlyAccTotalNftFee / stakedNfts) + vault1Account0_T16.nftIndex;     // 4 nfts staked frm t16-t31
        uint256 latestRpIndex = (newlyAccRealmPointsFee * 1E18 / stakedRp) + vault1Account0_T16.rpIndex;

        // check indices
        assertEq(vaultAccount.index, distribution.index); // must match distribution index
        assertEq(vaultAccount.nftIndex, latestNftIndex);  // 4 nfts staked frm t16-t31
        assertEq(vaultAccount.rpIndex, latestRpIndex);    

        // calc. accumulated rewards
        uint256 totalAccRewards = newlyAccRewards + vault1Account0_T16.totalAccRewards;
        // calc. accumulated fees
        uint256 latestAccCreatorFee = newlyAccCreatorFee + vault1Account0_T16.accCreatorRewards;
        uint256 latestAccTotalNftFee = newlyAccTotalNftFee + vault1Account0_T16.accNftStakingRewards;
        uint256 latestAccRealmPointsFee = newlyAccRealmPointsFee + vault1Account0_T16.accRealmPointsRewards;

        // heck accumulated rewards + fees
        assertEq(vaultAccount.totalAccRewards, totalAccRewards);
        assertEq(vaultAccount.accCreatorRewards, latestAccCreatorFee); 
        assertEq(vaultAccount.accNftStakingRewards, latestAccTotalNftFee); 
        assertEq(vaultAccount.accRealmPointsRewards, latestAccRealmPointsFee); 

        // rewardsAccPerUnitStaked: for moca stakers
        uint256 latestAccRewardsLessOfFees = newlyAccRewards - newlyAccCreatorFee - newlyAccTotalNftFee - newlyAccRealmPointsFee;
        uint256 expectedRewardsAccPerUnitStaked = (latestAccRewardsLessOfFees * 1E18 / stakedTokens) + vault1Account0_T16.rewardsAccPerUnitStaked;

        // rewardsAccPerUnitStaked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked); 

        // totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

    // vault2: created at t26, has no assets staked till t31
    function testVault2Account0_T31() public {
        DataTypes.Distribution memory distribution = getDistribution(0);
        DataTypes.Vault memory vault = pool.getVault(vaultId2);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 0);

        // Check indices match distribution at t31
        assertEq(vaultAccount.index, distribution.index);
        assertEq(vaultAccount.nftIndex, 0);
        assertEq(vaultAccount.rpIndex, 0);

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, 0);
        assertEq(vaultAccount.accCreatorRewards, 0);
        assertEq(vaultAccount.accNftStakingRewards, 0);
        assertEq(vaultAccount.accRealmPointsRewards, 0);

        // Check rewards per unit staked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, 0);  

        // Check claimed rewards
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

    // --------------- d0:vault1:users ---------------
    
    // stale: user1's account was last updated at t16. no action taken by user since.
    function testUser1_ForVault1Account0_T31() public {

        DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId1, 0);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);

        //--- user 1 last updated at t16
        uint256 stakedRP = user1Rp;
        uint256 stakedTokens = user1Moca;
        
        // Check indices match vault
        assertEq(userAccount.index, user1Account0_T16.index);
        assertEq(userAccount.nftIndex, user1Account0_T16.nftIndex);
        assertEq(userAccount.rpIndex, user1Account0_T16.rpIndex);

        // Check accumulated rewards
        assertEq(userAccount.accStakingRewards, user1Account0_T16.accStakingRewards); 
        assertEq(userAccount.accNftStakingRewards, user1Account0_T16.accNftStakingRewards);
        assertEq(userAccount.accRealmPointsRewards, user1Account0_T16.accRealmPointsRewards);

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0);
        assertEq(userAccount.claimedNftRewards, 0);
        assertEq(userAccount.claimedRealmPointsRewards, 0);
        assertEq(userAccount.claimedCreatorRewards, 0);
        
        //-------------check view fn----------------

        // Calculate pending unbooked rewards from t16-t31
        uint256 pendingAccStakingRewards = calculateRewards(stakedTokens, vaultAccount.rewardsAccPerUnitStaked, user1Account0_T16.index, 1E18);
        uint256 pendingAccNftStakingRewards = 0; // 0 nfts staked
        uint256 pendingAccRealmPointsRewards = calculateRewards(stakedRP, vaultAccount.rpIndex, user1Account0_T16.rpIndex, 1E18);

        // Add previously accumulated rewards from t16
        uint256 totalAccStakingRewards = pendingAccStakingRewards + user1Account0_T16.accStakingRewards;
        uint256 totalAccNftStakingRewards = pendingAccNftStakingRewards + user1Account0_T16.accNftStakingRewards;
        uint256 totalAccRealmPointsRewards = pendingAccRealmPointsRewards + user1Account0_T16.accRealmPointsRewards;

        // Calculate total expected rewards
        uint256 expectedClaimableRewards = totalAccStakingRewards + totalAccNftStakingRewards + totalAccRealmPointsRewards;
        if (user1 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

        // Check against pool.getClaimableRewards
        uint256 actualClaimableRewards = pool.getClaimableRewards(user1, vaultId1, 0);
        assertEq(actualClaimableRewards, expectedClaimableRewards);
    }

    // user2: last updated at t31, via migrateRp()
    function testUser2_ForVault1Account0_T31() public {
        DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId1, 0);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);

        //--- user2 last updated at t16: consider the emissions from t16-t31
        uint256 stakedRP = user2Rp;
        uint256 stakedTokens = user2Moca;
        uint256 numOfNfts = 4;

        // Check indices match vault@t31
        assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked, "userIndex mismatch");
        assertEq(userAccount.nftIndex, vaultAccount.nftIndex, "nftIndex mismatch");
        assertEq(userAccount.rpIndex, vaultAccount.rpIndex, "rpIndex mismatch");

        // Calculate expected rewards for user1's staked tokens
        uint256 latestAccStakingRewards = calculateRewards(stakedTokens, vaultAccount.rewardsAccPerUnitStaked, user2Account0_T16.index, 1E18) + user2Account0_T16.accStakingRewards;      
        // Calculate expected rewards for nft staking
        uint256 latestAccNftStakingRewards = ((vaultAccount.nftIndex - user2Account0_T16.nftIndex) * numOfNfts) + user2Account0_T16.accNftStakingRewards; 
        // Calculate expected rewards for rp staking
        uint256 latestAccRealmPointsRewards = calculateRewards(stakedRP, vaultAccount.rpIndex, user2Account0_T16.rpIndex, 1E18) + user2Account0_T16.accRealmPointsRewards;

        // Check accumulated rewards
        assertEq(userAccount.accStakingRewards, latestAccStakingRewards, "accStakingRewards mismatch"); 
        assertEq(userAccount.accNftStakingRewards, latestAccNftStakingRewards, "accNftStakingRewards mismatch");
        assertEq(userAccount.accRealmPointsRewards, latestAccRealmPointsRewards, "accRealmPointsRewards mismatch");

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
        assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
        assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
        assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");
        
        //--------------------------------
        
        // view fn: user2 gets their share of total rewards
        uint256 claimableRewards = pool.getClaimableRewards(user2, vaultId1, 0);
        
        uint256 expectedClaimableRewards = latestAccStakingRewards + latestAccNftStakingRewards + latestAccRealmPointsRewards;
        if (user2 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

        assertEq(claimableRewards, expectedClaimableRewards, "claimableRewards mismatch"); 

        // view fn should match account state
        assertEq(claimableRewards, userAccount.accStakingRewards + userAccount.accNftStakingRewards + userAccount.accRealmPointsRewards, "viewFn accountState mismatch");
    }

    // --------------- d0:vault2:users ---------------

    /*
        vault2 account's should be 0, except for vaultAccount.rewardsAccPerUnitStaked
        which should follow distribution.index

        nothing staked in vault2, so no rewards accrued to both user and vault.
    */

    // user1: last updated at t16. no action taken by user since.
    function testUser1_ForVault2Account0_T31() public {
        DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId2, 0);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 0);

        // Check indices match vault@t31
        assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked);
        assertEq(userAccount.nftIndex, vaultAccount.nftIndex);
        assertEq(userAccount.rpIndex, vaultAccount.rpIndex);

        // Check accumulated rewards
        assertEq(userAccount.accStakingRewards, 0, "accStakingRewards mismatch");
        assertEq(userAccount.accNftStakingRewards, 0, "accNftStakingRewards mismatch");
        assertEq(userAccount.accRealmPointsRewards, 0, "accRealmPointsRewards mismatch");

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
        assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
        assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
        assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");
    }

    // user2: last updated at t31, via migrateRp()
    function testUser2_ForVault2Account0_T31() public {
        DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId2, 0);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 0);

        // Check indices match vault@t31
        assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked);
        assertEq(userAccount.nftIndex, vaultAccount.nftIndex);
        assertEq(userAccount.rpIndex, vaultAccount.rpIndex);

        // Check accumulated rewards
        assertEq(userAccount.accStakingRewards, 0, "accStakingRewards mismatch");
        assertEq(userAccount.accNftStakingRewards, 0, "accNftStakingRewards mismatch");
        assertEq(userAccount.accRealmPointsRewards, 0, "accRealmPointsRewards mismatch");

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
        assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
        assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
        assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");
    }


    // ---------------- distribution 1 ----------------

    // STARTED AT T21
    function testDistribution1_T31() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        
        // static
        assertEq(distribution.distributionId, 1);
        assertEq(distribution.TOKEN_PRECISION, 1e18); 
        assertEq(distribution.endTime, 100 + 21);
        assertEq(distribution.startTime, 21);
        assertEq(distribution.emissionPerSecond, 1 ether);
        assertEq(distribution.manuallyEnded, 0);        
        
        uint256 expectedTotalEmitted = 1 ether * (31 - 21);
        // first index update
        uint256 expectedIndex = (expectedTotalEmitted * 1E18 / pool.totalBoostedStakedTokens());

        // dynamic
        assertEq(distribution.index, expectedIndex, "distribution index mismatch");
        assertEq(distribution.totalEmitted, expectedTotalEmitted, "total emitted rewards mismatch");
        assertEq(distribution.lastUpdateTimeStamp, 31, "last update timestamp mismatch");
    }
    
    // vault1 has assets staked, should reflect rewards: T21-T31 [d1 started at t21]
    function testVault1Account1_T31() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        DataTypes.Vault memory vault = pool.getVault(vaultId1);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);
        
        // vault assets: T16-T31 
        uint256 stakedRp = user1Rp + user2Rp;  
        uint256 stakedTokens = user1Moca + user2Moca;
        uint256 stakedNfts = 4;

        // -------------- check indexes --------------
            // prev. vault index
            uint256 prevVaultIndex = 0;     // first update

            // calc. newly accrued rewards       
            uint256 boostFactor = pool.PRECISION_BASE() + (stakedNfts * pool.NFT_MULTIPLIER());
            uint256 boostedRpBalance = stakedTokens * boostFactor / pool.PRECISION_BASE();
            uint256 newlyAccRewards = calculateRewards(boostedRpBalance, distribution.index, prevVaultIndex, 1E18); 
            // eval. rounding error
            uint256 newlyAccRewardsExpected = 10 ether;                   // d1 started @t21
            assertApproxEqAbs(newlyAccRewards, newlyAccRewardsExpected, 1800);

            // newly accrued fees since last update: based on newlyAccRewards
            uint256 newlyAccCreatorFee = newlyAccRewards * vault.creatorFeeFactor / 10_000;
            uint256 newlyAccTotalNftFee = newlyAccRewards * vault.nftFeeFactor / 10_000;         
            uint256 newlyAccRealmPointsFee = newlyAccRewards * vault.realmPointsFeeFactor / 10_000;
            // latest indices
            uint256 latestNftIndex = (newlyAccTotalNftFee / stakedNfts) + 0;     
            uint256 latestRpIndex = (newlyAccRealmPointsFee * 1E18 / stakedRp) + 0;

        // Check indices match distribution
        assertEq(vaultAccount.index, distribution.index, "vaultAccount index mismatch");
        assertEq(vaultAccount.nftIndex, latestNftIndex, "vaultAccount nftIndex mismatch");
        assertEq(vaultAccount.rpIndex, latestRpIndex, "vaultAccount rpIndex mismatch");
        
        // -------------- check accumulated rewards --------------

            // calc. accumulated rewards
            uint256 totalAccRewards = newlyAccRewards + 0;
            // calc. accumulated fees
            uint256 latestAccCreatorFee = newlyAccCreatorFee + 0;
            uint256 latestAccTotalNftFee = newlyAccTotalNftFee + 0;
            uint256 latestAccRealmPointsFee = newlyAccRealmPointsFee + 0;

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, totalAccRewards, "totalAccRewards mismatch");
        assertEq(vaultAccount.accCreatorRewards, latestAccCreatorFee, "accCreatorRewards mismatch");
        assertEq(vaultAccount.accNftStakingRewards, latestAccTotalNftFee, "accNftStakingRewards mismatch"); 
        assertEq(vaultAccount.accRealmPointsRewards, latestAccRealmPointsFee, "accRealmPointsRewards mismatch");

        // -------------- check rewardsAccPerUnitStaked --------------

            // rewardsAccPerUnitStaked: for moca stakers
            uint256 latestAccRewardsLessOfFees = newlyAccRewards - newlyAccCreatorFee - newlyAccTotalNftFee - newlyAccRealmPointsFee;
            uint256 expectedRewardsAccPerUnitStaked = (latestAccRewardsLessOfFees * 1E18 / stakedTokens) + 0;

        // Check rewardsAccPerUnitStaked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked, "rewardsAccPerUnitStaked mismatch");

        // Check totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0, "totalClaimedRewards mismatch");
    }

    // vault2: created at t26, has no assets staked till t31
    function testVault2Account1_T31() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        DataTypes.Vault memory vault = pool.getVault(vaultId2);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 1);

        // Check indices match distribution at t31
        assertEq(vaultAccount.index, distribution.index);
        assertEq(vaultAccount.nftIndex, 0);
        assertEq(vaultAccount.rpIndex, 0);

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, 0);
        assertEq(vaultAccount.accCreatorRewards, 0);
        assertEq(vaultAccount.accNftStakingRewards, 0);
        assertEq(vaultAccount.accRealmPointsRewards, 0);

        // Check rewards per unit staked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, 0);  

        // Check claimed rewards
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

    // --------------- d1:vault1:users ---------------

    
    // stale: user1's account was last updated at t16. no action taken by user since.
    function testUser1_ForVault1Account1_T31() public {

        DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId1, 1);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);

        //--- user 1 last updated at t16
        uint256 stakedRP = user1Rp;
        uint256 stakedTokens = user1Moca;
        
        // Check indices match vault
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
        
        //-------------check view fn----------------

        // Calculate pending unbooked rewards from t21-t31
        uint256 pendingAccStakingRewards = calculateRewards(stakedTokens, vaultAccount.rewardsAccPerUnitStaked, 0, 1E18);
        uint256 pendingAccNftStakingRewards = 0; // 0 nfts staked
        uint256 pendingAccRealmPointsRewards = calculateRewards(stakedRP, vaultAccount.rpIndex, 0, 1E18);

        // Add previously accumulated rewards from t16
        uint256 totalAccStakingRewards = pendingAccStakingRewards + 0;
        uint256 totalAccNftStakingRewards = pendingAccNftStakingRewards + 0;
        uint256 totalAccRealmPointsRewards = pendingAccRealmPointsRewards + 0;

        // Calculate total expected rewards
        uint256 expectedClaimableRewards = totalAccStakingRewards + totalAccNftStakingRewards + totalAccRealmPointsRewards;
        if (user1 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

        // Check against pool.getClaimableRewards
        uint256 actualClaimableRewards = pool.getClaimableRewards(user1, vaultId1, 1);
        assertEq(actualClaimableRewards, expectedClaimableRewards);
    }

    // user2: last updated at t31, via migrateRp()
    function testUser2_ForVault1Account1_T31() public {
        DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId1, 1);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 1);

        //--- user2 last updated at t16: consider the emissions from t16-t31
        uint256 stakedRP = user2Rp;
        uint256 stakedTokens = user2Moca;
        uint256 numOfNfts = 4;

        // Check indices match vault@t31
        assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked, "userIndex mismatch");
        assertEq(userAccount.nftIndex, vaultAccount.nftIndex, "nftIndex mismatch");
        assertEq(userAccount.rpIndex, vaultAccount.rpIndex, "rpIndex mismatch");

        // Check accumulated rewards
            uint256 prevUserIndex = 0;
            uint256 prevUserNftIndex = 0;
            uint256 prevUserRpIndex = 0;
            uint256 prevAccStakingRewards = 0;
            uint256 prevAccNftStakingRewards = 0;
            uint256 prevAccRealmPointsRewards = 0;

            // Calculate expected rewards for user1's staked tokens
            uint256 latestAccStakingRewards = calculateRewards(stakedTokens, vaultAccount.rewardsAccPerUnitStaked, prevUserIndex, 1E18) + prevAccStakingRewards;      
            // Calculate expected rewards for nft staking
            uint256 latestAccNftStakingRewards = ((vaultAccount.nftIndex - prevUserNftIndex) * numOfNfts) + prevAccNftStakingRewards; 
            // Calculate expected rewards for rp staking
            uint256 latestAccRealmPointsRewards = calculateRewards(stakedRP, vaultAccount.rpIndex, prevUserRpIndex, 1E18) + prevAccRealmPointsRewards;

        
        assertEq(userAccount.accStakingRewards, latestAccStakingRewards, "accStakingRewards mismatch"); 
        assertEq(userAccount.accNftStakingRewards, latestAccNftStakingRewards, "accNftStakingRewards mismatch");
        assertEq(userAccount.accRealmPointsRewards, latestAccRealmPointsRewards, "accRealmPointsRewards mismatch");

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
        assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
        assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
        assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");
        
        //--------------------------------
        
        // view fn: user2 gets their share of total rewards
        uint256 claimableRewards = pool.getClaimableRewards(user2, vaultId1, 1);
        
        uint256 expectedClaimableRewards = latestAccStakingRewards + latestAccNftStakingRewards + latestAccRealmPointsRewards;
        if (user2 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

        assertEq(claimableRewards, expectedClaimableRewards, "claimableRewards mismatch"); 

        // view fn should match account state
        assertEq(claimableRewards, userAccount.accStakingRewards + userAccount.accNftStakingRewards + userAccount.accRealmPointsRewards, "viewFn accountState mismatch");
    }

    // --------------- d1:vault2:users ---------------

    // user1: last updated at t16. no action taken by user since.
    function testUser1_ForVault2Account1_T31() public {
        DataTypes.UserAccount memory userAccount = getUserAccount(user1, vaultId2, 1);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 1);

        // Check indices match vault@t31
        assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked);
        assertEq(userAccount.nftIndex, vaultAccount.nftIndex);
        assertEq(userAccount.rpIndex, vaultAccount.rpIndex);

        // Check accumulated rewards
        assertEq(userAccount.accStakingRewards, 0, "accStakingRewards mismatch");
        assertEq(userAccount.accNftStakingRewards, 0, "accNftStakingRewards mismatch");
        assertEq(userAccount.accRealmPointsRewards, 0, "accRealmPointsRewards mismatch");

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
        assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
        assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
        assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");
    }

    // user2: last updated at t31, via migrateRp(). 
    // user2 staked nothing into vault2 till T31
    function testUser2_ForVault2Account1_T31() public {
        DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId2, 1);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 1);

        //--- user2 last updated at t31: consider the emissions from t21-t31
        uint256 stakedRP = 0;
        uint256 stakedTokens = 0;
        uint256 numOfNfts = 0;

        // Check indices match vault@t31
        assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked, "userIndex mismatch");
        assertEq(userAccount.nftIndex, vaultAccount.nftIndex, "nftIndex mismatch");
        assertEq(userAccount.rpIndex, vaultAccount.rpIndex, "rpIndex mismatch");

        // Check accumulated rewards       
        assertEq(userAccount.accStakingRewards, 0, "accStakingRewards mismatch"); 
        assertEq(userAccount.accNftStakingRewards, 0, "accNftStakingRewards mismatch");
        assertEq(userAccount.accRealmPointsRewards, 0, "accRealmPointsRewards mismatch");

        // Check claimed rewards
        assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
        assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
        assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
        assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");
        
        //--------------------------------
        
        // view fn: user2 gets their share of total rewards
        uint256 claimableRewards = pool.getClaimableRewards(user2, vaultId2, 1);
        
        uint256 expectedClaimableRewards = 0 + 0 + 0;
        if (user2 == pool.getVault(vaultId2).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

        assertEq(claimableRewards, expectedClaimableRewards, "claimableRewards mismatch"); 

        // view fn should match account state
        assertEq(claimableRewards, userAccount.accStakingRewards + userAccount.accNftStakingRewards + userAccount.accRealmPointsRewards, "viewFn accountState mismatch");
    }

    // ---------------- others ----------------

    // TODO connector fns
    // 1. user2 cannot unstake nfts not present within vault1
    // 2. user2 can unstake the correct nfts from vault1

    // user2 unstakes half their tokens and 2 nfts, from vault1
    function testUser2CanUnstakeAssets_T31() public {
        // Get initial balances
        DataTypes.Vault memory vaultBefore = pool.getVault(vaultId1);
        DataTypes.User memory user2VaultBefore = pool.getUser(user2, vaultId1);

        uint256 poolNftsBefore = pool.totalStakedNfts();
        uint256 poolTokensBefore = pool.totalStakedTokens();
        uint256 poolBoostedTokensBefore = pool.totalBoostedStakedTokens(); // 2.1e20
        uint256 poolBoostedRpBefore = pool.totalBoostedRealmPoints(); // 1.9e21

        // user2 unstakes first 2 NFTs and half tokens from vault1
        uint256 tokenAmount = user2Moca/2;
        uint256 tokenAmountBoosted = (tokenAmount * vaultBefore.totalBoostFactor) / pool.PRECISION_BASE();
        console2.log("tokenAmountBoosted", tokenAmountBoosted);
        console2.log("vaultBefore.totalBoostFactor", vaultBefore.totalBoostFactor);

        uint256[] memory nftsToUnstake = new uint256[](2);
            nftsToUnstake[0] = user2NftsArray[0];
            nftsToUnstake[1] = user2NftsArray[1];
        
        // need to negate the tokens being unstaked
        uint256 deltaBoostFactor = 2 * pool.NFT_MULTIPLIER();
        uint256 deltaVaultBoostedStakedTokens = ((vaultBefore.stakedTokens - tokenAmount) * deltaBoostFactor) / pool.PRECISION_BASE();
        uint256 deltaVaultBoostedRealmPoints = (vaultBefore.stakedRealmPoints * deltaBoostFactor) / pool.PRECISION_BASE();

        vm.startPrank(user2);
            vm.expectEmit(true, true, true, true);
            emit UnstakedTokens(user2, vaultId1, tokenAmount, tokenAmountBoosted);

            vm.expectEmit(true, true, true, true);
            emit UnstakedNfts(user2, vaultId1, nftsToUnstake, deltaVaultBoostedStakedTokens, deltaVaultBoostedRealmPoints);

            pool.unstake(vaultId1, tokenAmount, nftsToUnstake);
        vm.stopPrank();

        // Check vault balances updated
        DataTypes.Vault memory vaultAfter = pool.getVault(vaultId1);
        assertEq(vaultAfter.stakedTokens, vaultBefore.stakedTokens - tokenAmount, "Vault tokens not reduced correctly");
        assertEq(vaultAfter.stakedNfts, vaultBefore.stakedNfts - 2, "Vault NFTs not reduced correctly");

        // Check pool balances updated
        assertEq(pool.totalStakedNfts(), poolNftsBefore - 2, "Pool NFTs not reduced correctly");
        assertEq(pool.totalStakedTokens(), poolTokensBefore - tokenAmount, "Pool tokens not reduced correctly");

        // Check boosted balances updated
        uint256 expectedVaultBoostFactor = pool.PRECISION_BASE() + ((vaultAfter.stakedNfts) * pool.NFT_MULTIPLIER());
        uint256 expectedVaultBoostedTokens = (vaultAfter.stakedTokens * expectedVaultBoostFactor) / pool.PRECISION_BASE();
        uint256 expectedVaultBoostedRp = (vaultAfter.stakedRealmPoints * expectedVaultBoostFactor) / pool.PRECISION_BASE();

        // vault
        assertEq(vaultAfter.totalBoostFactor, expectedVaultBoostFactor, "Vault boost factor not updated correctly");
        assertEq(vaultAfter.boostedStakedTokens, expectedVaultBoostedTokens, "Vault boosted tokens not updated correctly");
        assertEq(vaultAfter.boostedRealmPoints, expectedVaultBoostedRp, "Vault boosted RP not updated correctly");
        
        // pool
        assertEq(pool.totalBoostedStakedTokens(), poolBoostedTokensBefore - tokenAmountBoosted - deltaVaultBoostedStakedTokens, "Pool boosted tokens not updated correctly");
        assertEq(pool.totalBoostedRealmPoints(), poolBoostedRpBefore - deltaVaultBoostedRealmPoints, "Pool boosted RP not updated correctly");
    }
}


abstract contract StateT36_User2UnstakesFromVault1 is StateT31_User2MigrateRpToVault2 {
    
    // for reference
    DataTypes.Distribution distribution0_T36;
    DataTypes.Distribution distribution1_T36;
    //vault1
    DataTypes.VaultAccount vault1Account0_T36;
    DataTypes.VaultAccount vault1Account1_T36;
    //vault2
    DataTypes.VaultAccount vault2Account0_T36;
    DataTypes.VaultAccount vault2Account1_T36;
    //user1
    DataTypes.UserAccount user1Account0_T36;
    DataTypes.UserAccount user1Account1_T36;
    //user2
    DataTypes.UserAccount user2Account0_T36;
    DataTypes.UserAccount user2Account1_T36;

    function setUp() public virtual override {
        super.setUp();

        vm.warp(36);

        uint256[] memory nftsToUnstake = new uint256[](2);
        nftsToUnstake[0] = user2NftsArray[0];
        nftsToUnstake[1] = user2NftsArray[1];

        vm.startPrank(user2);
            // user2 unstakes half of tokens and 2nfts
            pool.unstake(vaultId1, user2Moca/2, nftsToUnstake);
        vm.stopPrank();

        // save state
        distribution0_T36 = getDistribution(0);
        distribution1_T36 = getDistribution(1);
        vault1Account0_T36 = getVaultAccount(vaultId1, 0);
        vault1Account1_T36 = getVaultAccount(vaultId1, 1);  
        vault2Account0_T36 = getVaultAccount(vaultId2, 0);
        vault2Account1_T36 = getVaultAccount(vaultId2, 1);
        user1Account0_T36 = getUserAccount(user1, vaultId1, 0);
        user1Account1_T36 = getUserAccount(user1, vaultId1, 1);
        user2Account0_T36 = getUserAccount(user2, vaultId1, 0);
        user2Account1_T36 = getUserAccount(user2, vaultId1, 1);
    }   
}   

contract StateT36_User2UnstakesFromVault1Test is StateT36_User2UnstakesFromVault1 {

    /**
        note: test stuff related to unstaking tokens+nfts
     */

    // ---------------- base assets ----------------

    function testPool_T36() public {
        DataTypes.Vault memory vault1 = pool.getVault(vaultId1);
        DataTypes.Vault memory vault2 = pool.getVault(vaultId2);

        // Check total creation NFTs - unchanged
        assertEq(pool.totalCreationNfts(), 6);
        assertEq(pool.totalCreationNfts(), vault1.creationTokenIds.length + vault2.creationTokenIds.length);

        // Check total staked assets
        assertEq(pool.totalStakedNfts(), 2);                         // user2 unstaked 2 nfts frm vault1
        assertEq(pool.totalStakedTokens(), user1Moca + user2Moca/2); // user2 unstaked half of tokens
        assertEq(pool.totalStakedRealmPoints(), user1Rp + user2Rp);  // unchanged: migrateRp
        
        // check boosted assets
        
            // only vault 1 assets enjoy boosting
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

    /**
        T31 - T36: user2 migrates half his RP to vault2
         distr_0 + distr_1 updated.
         vault1 accounts updated.
         vault2 accounts NOT updated at T36 [stale T31 indexes]
         user2 accounts updated. [check: T31-T36]
         user1 NOT updated - stale. [lastupdate: t16]
         > test vault1, vault2, user2 accounts

        vault2 created at T26:
         accrues SP from T31-T36, due to migrated rp.
         does not accrue rewards from d1, no tokens staked.
         not updated at T36. stale as per T31
    */

    // ---------------- distribution 0 ----------------

    // updated: T31-T36
    function testDistribution0_T36() public {

        DataTypes.Distribution memory distribution = getDistribution(0);

        // static
        assertEq(distribution.distributionId, 0);
        assertEq(distribution.TOKEN_PRECISION, 1e18); 
        assertEq(distribution.endTime, 0);
        assertEq(distribution.startTime, 1);
        assertEq(distribution.emissionPerSecond, 1 ether);
        assertEq(distribution.manuallyEnded, 0);        
        
        /** index calc: t31 - t36   [delta: 5]
            - prev. index: 3.825e16 [t31: 38253968253968253]
            - totalEmittedSinceLastUpdate: 5e18 SP
            - totalRpStaked: (500 + 500) + 500
            - boostableRp: (500 + 500), unboostableRp: 500
            - totalBoostFactor: 1000 * 4 / PRECISION_BASE = 40% [40/100]
            - totalBoostedRP: [(500 + 500) * 1.4] + 500 = 1900e18
            index = 3.825e16 + [5e18 SP / 1900 RP]
                  = 38253968253968253 + 2631578947368421
                  ~ 4.0885547e16 [40885547201336674]
         */

        uint256 numOfNftsStaked = 4;                            // user2: 4nfts staked for t31-36
        uint256 boostableRP = user1Rp + user2Rp/2;
        uint256 boostFactor = pool.PRECISION_BASE() + (numOfNftsStaked * pool.NFT_MULTIPLIER());
        uint256 totalBoostedRp = boostableRP * boostFactor / pool.PRECISION_BASE() + user2Rp/2;

        uint256 indexDelta = 5 ether * 1E18 / totalBoostedRp;
        uint256 expectedIndex = distribution0_T31.index + indexDelta;
        console.log("distribution0_T31.index", distribution0_T31.index);
        console.log("indexDelta", indexDelta);
        console.log("expectedIndex", expectedIndex);
        assertEq(expectedIndex, 40885547201336674); // 4.088e16
        
        // dynamic
        assertEq(distribution.index, expectedIndex);    // 4.088e16
        assertEq(distribution.totalEmitted, distribution0_T31.totalEmitted + 5 ether);
        assertEq(distribution.lastUpdateTimeStamp, 36);
    }

    function testVault1Account0_T36() public {
        DataTypes.Distribution memory distribution = getDistribution(0);
        DataTypes.Vault memory vault1 = pool.getVault(vaultId1);
        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);
        
        /** T31 - T36
            stakedTokens: user1Moca + user2Moca
            stakedRp: user1Rp + user2Rp/2 [changed at T31]
            stakedNfts: 4
         */

        // vault assets 
        uint256 stakedRp = vault1_T31.stakedRealmPoints;  
        uint256 stakedTokens = vault1_T31.stakedTokens;
        uint256 stakedNfts = vault1_T31.stakedNfts;
        uint256 prevVaultIndex = vault1Account0_T31.index;
        uint256 boostedRp = vault1_T31.boostedRealmPoints;

        uint256 poolBoostedRp = vault1_T31.boostedRealmPoints + vault2_T31.boostedRealmPoints;

        // check indices

            // calc. newly accrued rewards       
            uint256 newlyAccRewards = calculateRewards(boostedRp, distribution0_T36.index, prevVaultIndex, 1E18); 
                // eval. rounding error
                uint256 emittedRewards = 5 ether;
                uint256 vault1ShareOfEmittedRewards = (boostedRp * emittedRewards) / poolBoostedRp;
                assertApproxEqAbs(newlyAccRewards, vault1ShareOfEmittedRewards, 1800);

            // newly accrued fees since last update: based on newlyAccRewards
            uint256 newlyAccCreatorFee = newlyAccRewards * 1000 / 10_000;
            uint256 newlyAccTotalNftFee = newlyAccRewards * 1000 / 10_000;         
            uint256 newlyAccRealmPointsFee = newlyAccRewards * 1000 / 10_000;
            
            // latest indices
            uint256 latestNftIndex = (newlyAccTotalNftFee / stakedNfts) + vault1Account0_T31.nftIndex;     // 4 nfts staked frm t31-t36
            uint256 latestRpIndex = (newlyAccRealmPointsFee * 1E18 / stakedRp) + vault1Account0_T31.rpIndex;

        // check indices
        assertEq(vaultAccount.index, distribution.index); // must match distribution index
        assertEq(vaultAccount.nftIndex, latestNftIndex);  // 4 nfts staked frm t31-t36
        assertEq(vaultAccount.rpIndex, latestRpIndex);    

        // calc. accumulated rewards
        uint256 totalAccRewards = newlyAccRewards + vault1Account0_T31.totalAccRewards;
        // calc. accumulated fees
        uint256 latestAccCreatorFee = newlyAccCreatorFee + vault1Account0_T31.accCreatorRewards;
        uint256 latestAccTotalNftFee = newlyAccTotalNftFee + vault1Account0_T31.accNftStakingRewards;
        uint256 latestAccRealmPointsFee = newlyAccRealmPointsFee + vault1Account0_T31.accRealmPointsRewards;

        // heck accumulated rewards + fees
        assertEq(vaultAccount.totalAccRewards, totalAccRewards);
        assertEq(vaultAccount.accCreatorRewards, latestAccCreatorFee); 
        assertEq(vaultAccount.accNftStakingRewards, latestAccTotalNftFee); 
        assertEq(vaultAccount.accRealmPointsRewards, latestAccRealmPointsFee); 

        // rewardsAccPerUnitStaked: for moca stakers
        uint256 latestAccRewardsLessOfFees = newlyAccRewards - newlyAccCreatorFee - newlyAccTotalNftFee - newlyAccRealmPointsFee;
        uint256 expectedRewardsAccPerUnitStaked = (latestAccRewardsLessOfFees * 1E18 / stakedTokens) + vault1Account0_T31.rewardsAccPerUnitStaked;

        // rewardsAccPerUnitStaked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, expectedRewardsAccPerUnitStaked); 

        // totalClaimedRewards
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

    // accrues SP from T31-T36, but NOT updated at T36; stale as per T31
    function testVault2Account0_T36() public {
        DataTypes.Distribution memory distribution = getDistribution(0);
        DataTypes.Vault memory vault = pool.getVault(vaultId2);

        DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 0);

        // Check indices match distribution at t31
        assertEq(vaultAccount.index, distribution0_T31.index);
        assertEq(vaultAccount.nftIndex, 0);
        assertEq(vaultAccount.rpIndex, 0);

        // Check accumulated rewards
        assertEq(vaultAccount.totalAccRewards, 0);
        assertEq(vaultAccount.accCreatorRewards, 0);
        assertEq(vaultAccount.accNftStakingRewards, 0);
        assertEq(vaultAccount.accRealmPointsRewards, 0);

        // Check rewards per unit staked
        assertEq(vaultAccount.rewardsAccPerUnitStaked, 0);  

        // Check claimed rewards
        assertEq(vaultAccount.totalClaimedRewards, 0);
    }

        // --------------- d0:vault1:users ---------------

        // stale: user1's account was last updated at t16. no action taken by user since.
        /*function testUser1_ForVault1Account0_T36() public {}*/

        // updated at T36, via unstake()
        function testUser2_ForVault1Account0_T36() public {
            DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId1, 0);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId1, 0);

            //--- user2 last updated at t31: consider the emissions from t31-t36
            uint256 stakedRP = user2Rp/2;
            uint256 stakedTokens = user2Moca;
            uint256 numOfNfts = 4;

            // Check indices match vault@t36
            assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked, "userIndex mismatch");
            assertEq(userAccount.nftIndex, vaultAccount.nftIndex, "nftIndex mismatch");
            assertEq(userAccount.rpIndex, vaultAccount.rpIndex, "rpIndex mismatch");

            // Check accumulated rewards

                // Calculate expected rewards for user1's staked tokens
                uint256 prevUserIndex = user2Account0_T31.index;
                uint256 prevAccStakingRewards = user2Account0_T31.accStakingRewards;
                uint256 latestAccStakingRewards = calculateRewards(stakedTokens, vaultAccount.rewardsAccPerUnitStaked, prevUserIndex, 1E18) + prevAccStakingRewards;      
                // Calculate expected rewards for nft staking
                uint256 prevAccNftStakingRewards = user2Account0_T31.accNftStakingRewards;
                uint256 latestAccNftStakingRewards = ((vaultAccount.nftIndex - user2Account0_T31.nftIndex) * numOfNfts) + prevAccNftStakingRewards; 
                // Calculate expected rewards for rp staking
                uint256 prevRpIndex = user2Account0_T31.rpIndex;
                uint256 prevAccRealmPointsRewards = user2Account0_T31.accRealmPointsRewards;
                uint256 latestAccRealmPointsRewards = calculateRewards(stakedRP, vaultAccount.rpIndex, prevRpIndex, 1E18) + prevAccRealmPointsRewards;

            assertEq(userAccount.accStakingRewards, latestAccStakingRewards, "accStakingRewards mismatch"); 
            assertEq(userAccount.accNftStakingRewards, latestAccNftStakingRewards, "accNftStakingRewards mismatch");
            assertEq(userAccount.accRealmPointsRewards, latestAccRealmPointsRewards, "accRealmPointsRewards mismatch");

            // Check claimed rewards
            assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
            assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
            assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
            assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");
            
            //--------------------------------
            
            // view fn: user2 gets their share of total rewards
            uint256 claimableRewards = pool.getClaimableRewards(user2, vaultId1, 0);
            
            uint256 expectedClaimableRewards = latestAccStakingRewards + latestAccNftStakingRewards + latestAccRealmPointsRewards;
            if (user2 == pool.getVault(vaultId1).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

            assertEq(claimableRewards, expectedClaimableRewards, "claimableRewards mismatch"); 

            // view fn should match account state
            assertEq(claimableRewards, userAccount.accStakingRewards + userAccount.accNftStakingRewards + userAccount.accRealmPointsRewards, "viewFn accountState mismatch");
        }


        // --------------- d0:vault2:users ---------------

        // stale: user1's account was last updated at t16. no action taken by user since.
        /*function testUser1_ForVault2Account0_T36() public {}*/
        
        // stale: updated at T31, via migrateRp()
        function testUser2_ForVault2Account0_T36() public {
            DataTypes.UserAccount memory userAccount = getUserAccount(user2, vaultId2, 0);
            DataTypes.VaultAccount memory vaultAccount = getVaultAccount(vaultId2, 0);

            //--- user2 last updated at t31: consider the emissions from t31-t36
            uint256 stakedRP = user2Rp/2;
            uint256 stakedTokens = 0; // no tokens staked in vault2
            uint256 numOfNfts = 0; // no NFTs staked in vault2

            // Check indices match vault@t36
            assertEq(userAccount.index, vaultAccount.rewardsAccPerUnitStaked, "userIndex mismatch");
            assertEq(userAccount.nftIndex, vaultAccount.nftIndex, "nftIndex mismatch");
            assertEq(userAccount.rpIndex, vaultAccount.rpIndex, "rpIndex mismatch");

            // Check accumulated rewards

                // Calculate expected rewards for user2's staked tokens 
                //uint256 prevUserIndex = user2Account0_T31.index;
                //uint256 prevAccStakingRewards = user2Account0_T31.accStakingRewards;
                //uint256 latestAccStakingRewards = calculateRewards(stakedTokens, vaultAccount.rewardsAccPerUnitStaked, prevUserIndex, 1E18) + prevAccStakingRewards;      
                // Calculate expected rewards for nft staking
                //uint256 prevAccNftStakingRewards = user2Account0_T31.accNftStakingRewards;
                //uint256 latestAccNftStakingRewards = ((vaultAccount.nftIndex - user2Account0_T31.nftIndex) * numOfNfts) + prevAccNftStakingRewards; 
                // Calculate expected rewards for rp staking
                //uint256 prevRpIndex = user2Vault2Account0_T31.rpIndex;
                //uint256 prevAccRealmPointsRewards = user2Vault2Account0_T31.accRealmPointsRewards;
                //uint256 latestAccRealmPointsRewards = calculateRewards(stakedRP, vaultAccount.rpIndex, prevRpIndex, 1E18) + prevAccRealmPointsRewards;

            assertEq(userAccount.accStakingRewards, 0, "accStakingRewards mismatch"); 
            assertEq(userAccount.accNftStakingRewards, 0, "accNftStakingRewards mismatch");
            assertEq(userAccount.accRealmPointsRewards, 0, "accRealmPointsRewards mismatch");

            // Check claimed rewards
            assertEq(userAccount.claimedStakingRewards, 0, "claimedStakingRewards mismatch");
            assertEq(userAccount.claimedNftRewards, 0, "claimedNftRewards mismatch");
            assertEq(userAccount.claimedRealmPointsRewards, 0, "claimedRealmPointsRewards mismatch");
            assertEq(userAccount.claimedCreatorRewards, 0, "claimedCreatorRewards mismatch");
            
            //--------------------------------
            
            // view fn: user2 gets their share of total rewards
            uint256 claimableRewards = pool.getClaimableRewards(user2, vaultId2, 0);
            
            // calc. expected claimable rewards
                uint256 latestAccStakingRewards = 0;      
                uint256 latestAccNftStakingRewards = 0;
                
                uint256 vault2ShareOfEmissions = (5 ether * vault2_T31.boostedRealmPoints) / (vault1_T31.boostedRealmPoints + vault2_T31.boostedRealmPoints);
                // vault2 has no staked tokens, only staked RP - receives only rp fee
                uint256 user2vault2ReceivedRewards = (vault2ShareOfEmissions * (vault2_T31.realmPointsFeeFactor + vault2_T31.creatorFeeFactor)) / pool.PRECISION_BASE();
                uint256 latestAccRealmPointsRewards = user2vault2ReceivedRewards;

            uint256 expectedClaimableRewards = latestAccStakingRewards + latestAccNftStakingRewards + latestAccRealmPointsRewards;
            //if (user2 == pool.getVault(vaultId2).creator) expectedClaimableRewards += vaultAccount.accCreatorRewards;

            assertApproxEqAbs(claimableRewards, expectedClaimableRewards, 27, "claimableRewards mismatch");

            // view fn should match account state
            //assertEq(claimableRewards, userAccount.accStakingRewards + userAccount.accNftStakingRewards + userAccount.accRealmPointsRewards, "viewFn accountState mismatch");
        }


    // ---------------- distribution 1 ----------------
    
    // STARTED AT T21
    function testDistribution1_T36() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        
        // static
        assertEq(distribution.distributionId, 1);
        assertEq(distribution.TOKEN_PRECISION, 1e18); 
        assertEq(distribution.endTime, 100 + 21);
        assertEq(distribution.startTime, 21);
        assertEq(distribution.emissionPerSecond, 1 ether);
        assertEq(distribution.manuallyEnded, 0);        
        
            // emissions for T31-T36; no change in pool.totalBoostedStakedTokens()
            uint256 expectedTotalEmitted = 1 ether * (36 - 31);
            uint256 indexDelta = expectedTotalEmitted * 1E18 / (vault1_T31.boostedStakedTokens + vault2_T31.boostedStakedTokens);
            uint256 expectedIndex = distribution1_T31.index + indexDelta;

        // dynamic
        assertEq(distribution.index, expectedIndex, "distribution index mismatch");
        assertEq(distribution.totalEmitted, expectedTotalEmitted, "total emitted rewards mismatch");
        assertEq(distribution.lastUpdateTimeStamp, 36, "last update timestamp mismatch");
    }

    function testVault1Account1_T36() public {}
    
    // vault2: acrrues no token rewards
    function testVault2Account1_T36() public {}

        // --------------- d1:vault1:users ---------------

        // stale: user1's account was last updated at t16. no action taken by user since.
        /*function testUser1_ForVault1Account1_T36() public {}*/

        // updated as part of migrate()
        function testUser2_ForVault1Account1_T36() public {}

        // --------------- d1:vault2:users ---------------

        // stale: user1's account was last updated at t16. no action taken by user since.
        /*function testUser1_ForVault2Account1_T36() public {}*/

        // updated as part of migrate()
        function testUser2_ForVault2Account1_T36() public {}


}

