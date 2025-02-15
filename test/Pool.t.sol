// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import "./TestingHarness.sol";

abstract contract StateDeploy is TestingHarness {    

    function setUp() public virtual override {
        super.setUp();
    }
}

contract StateDeployTest is StateDeploy {

    function testConstructor() public {
        assertEq(address(pool.NFT_REGISTRY()), address(nftRegistry));
        assertEq(address(pool.STAKED_TOKEN()), address(mocaToken));

        assertEq(pool.startTime(), startTime);

        assertEq(pool.NFT_MULTIPLIER(), nftMultiplier);
        assertEq(pool.CREATION_NFTS_REQUIRED(), creationNftsRequired);
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

abstract contract StateStarted is StateDeploy {

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

        // starting point: T1
        vm.warp(pool.startTime()); 
        console.log("Current timestamp:", block.timestamp);
    }
}

contract StateStartedTest is StateStarted {

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

abstract contract StateCreateVault is StateStarted {

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

contract StateCreateVaultTest is StateCreateVault {

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


abstract contract StateStakeAssets is StateCreateVault {
    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(user2);
        
        // User2 stakes half their tokens
        mocaToken.approve(address(pool), user2Moca/2);
        pool.stakeTokens(vaultId1, user2Moca/2);

        // User2 stakes 2 nfts
        uint256[] memory nftsToStake = new uint256[](2); 
        nftsToStake[0] = user2NftsArray[0];
        nftsToStake[1] = user2NftsArray[1];
        pool.stakeNfts(vaultId1, nftsToStake);
        
        vm.stopPrank();
    }
}

contract StateStakeAssetsTest is StateStakeAssets {

    function testGetVaultReturnsCorrectData() public {
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

        // Verify staked assets from setUp()
        assertEq(vault.stakedTokens, user2Moca/2);
        assertEq(vault.stakedNfts, 2);
        assertEq(vault.stakedRealmPoints, 0);
    }
}
