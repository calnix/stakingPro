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

    function testVault1Account_T1() public {
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
    }
}


//note: 5 seconds delta. 5 ether of staking power emitted @1ether/second
contract StateT6_User2StakeAssetsToVault1Test is StateT6_User2StakeAssetsToVault1 {
    // ---------------- distribution 0 ----------------

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

    function testVault1Account_T6() public {
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
    
}

