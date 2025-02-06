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
        pool.createVault(user1NftsArray, nftFeeFactor, creatorFeeFactor, realmPointsFeeFactor);
    }

}