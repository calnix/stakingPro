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
            uint32 dstEid = 0;
            bytes32 tokenAddress = 0x00;
        pool.setupDistribution(distributionId, distributionStartTime, distributionEndTime, emissionPerSecond, tokenPrecision, dstEid, tokenAddress);        

        // starting point: T1
        vm.warp(pool.startTime()); 
        console.log("Current timestamp:", block.timestamp);
    }
}

contract StateStartedTest is StateStarted {

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

    bytes32 vaultId = 0x8fbe8a20f950b11703e51f11dee9f00d9fa0ebd091cc4f695909e860e994944b;

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

    function testCannotCreateVaultWithLockedNfts() public {
        vm.prank(user1);
        vm.expectRevert();
        pool.createVault(user1NftsArray, 1000, 1000, 1000);
    }
}
