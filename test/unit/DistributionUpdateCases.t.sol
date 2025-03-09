// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT0.t.sol";

abstract contract StateT1_Started is StateT0_DeployAndSetupStakingPower {

    function setUp() public virtual override {
        super.setUp();

        //T1
        vm.warp(pool.startTime());
    }
}

abstract contract StateT1_CreateVault1 is StateT1_Started {

    bytes32 public vaultId1 = 0x8fbe8a20f950b11703e51f11dee9f00d9fa0ebd091cc4f695909e860e994944b;

    function setUp() public virtual override {
        super.setUp();
        
        vm.startPrank(user1);

            uint256 nftFeeFactor = 1000;
            uint256 creatorFeeFactor = 1000; 
            uint256 realmPointsFeeFactor = 1000;
            pool.createVault(user1NftsArray, nftFeeFactor, creatorFeeFactor, realmPointsFeeFactor);

        vm.stopPrank();
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


// --------- case 1: setup new distribution ---------
abstract contract NewDistribution_Case1 is StateT1_User1StakeAssetsToVault1 {

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(operator);

            uint256 distributionId = 1;
            uint256 distributionStartTime = 1;
            uint256 distributionEndTime = 101;
            uint256 emissionPerSecond = 1 ether;
            uint256 tokenPrecision = 1E18;
            bytes32 tokenAddress = rewardsVault.addressToBytes32(address(rewardsToken1));

        pool.setupDistribution(distributionId, distributionStartTime, distributionEndTime, emissionPerSecond, tokenPrecision, dstEid, tokenAddress); 

        vm.stopPrank();

        // MINT + DEPOSIT
        vm.startPrank(depositor);

            // mint needed
            uint256 totalRequired = (distributionEndTime - distributionStartTime) * emissionPerSecond;
            rewardsToken1.mint(depositor, totalRequired);
            rewardsToken1.approve(address(rewardsVault), totalRequired);
            // deposit
            rewardsVault.deposit(distributionId, 60 ether, depositor);

        vm.stopPrank();
    }
}

contract NewDistribution_Case1Test is NewDistribution_Case1 {

    function test_NewDistribution() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        assertEq(distribution.lastUpdateTimeStamp, 1);
        
        // get rewardsVault state
        (, , uint256 totalRequired, uint256 totalClaimed, uint256 totalDeposited) = rewardsVault.distributions(1);
        assertEq(totalRequired, 100 ether, "totalRequired failed");
        assertEq(totalDeposited, 60 ether, "totalDeposited failed");
        assertEq(totalClaimed, 0 ether, "totalClaimed failed");
    }
}

// --------- case 1: T50 ---------

abstract contract T50_Case1 is NewDistribution_Case1 {

    function setUp() public virtual override {
        super.setUp();
        
        vm.warp(50);

        vm.startPrank(operator);
            uint256 distributionId = 1;
            uint256 newStartTime = 0;
            uint256 newEndTime = 201;
            uint256 newEmissionPerSecond = 2 ether;
            pool.updateDistribution(distributionId, newStartTime, newEndTime, newEmissionPerSecond);
        vm.stopPrank();
    }
}

contract T50_Case1Test is T50_Case1 {

    function test_T50() public {
        DataTypes.Distribution memory distribution = getDistribution(1);       
        // new vars
        assertEq(distribution.emissionPerSecond, 2 ether, "newEmissionPerSecond failed");
        assertEq(distribution.endTime, 201, "newEndTime failed");
        // so far
        assertEq(distribution.lastUpdateTimeStamp, 50, "lastUpdateTimeStamp failed");
        assertEq(distribution.totalEmitted, 50 ether, "totalEmitted failed");

        // get rewardsVault state
        (, , uint256 newTotalRequired, uint256 totalClaimed, uint256 totalDeposited) = rewardsVault.distributions(1);
        assertEq(newTotalRequired, 300 ether, "newTotalRequired failed");
        // old
        assertEq(totalDeposited, 60 ether, "totalDeposited failed");
        assertEq(totalClaimed, 0 ether, "totalClaimed failed");

        //
        uint256 remainingDuration = distribution.endTime - block.timestamp;
        uint256 newDepositable = (remainingDuration * distribution.emissionPerSecond) - totalDeposited;
        assertEq(newDepositable, 290 ether, "newDepositable failed");
    }
}

// ================================================================

// --------- case 2: setup new distribution ---------
abstract contract NewDistribution_Case2 is StateT1_User1StakeAssetsToVault1 {

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(operator);

            uint256 distributionId = 1;
            uint256 distributionStartTime = 1;
            uint256 distributionEndTime = 101;
            uint256 emissionPerSecond = 1 ether;
            uint256 tokenPrecision = 1E18;
            bytes32 tokenAddress = rewardsVault.addressToBytes32(address(rewardsToken1));

        pool.setupDistribution(distributionId, distributionStartTime, distributionEndTime, emissionPerSecond, tokenPrecision, dstEid, tokenAddress); 

        vm.stopPrank();

        // MINT + DEPOSIT
        vm.startPrank(depositor);

            // mint needed
            uint256 totalRequired = (distributionEndTime - distributionStartTime) * emissionPerSecond;
            rewardsToken1.mint(depositor, totalRequired);
            rewardsToken1.approve(address(rewardsVault), totalRequired);
            // deposit
            rewardsVault.deposit(distributionId, 40 ether, depositor);

        vm.stopPrank();
    }
}

contract NewDistribution_Case2Test is NewDistribution_Case2 {

    function test_NewDistribution() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        assertEq(distribution.lastUpdateTimeStamp, 1);
        
        // get rewardsVault state
        (, , uint256 totalRequired, uint256 totalClaimed, uint256 totalDeposited) = rewardsVault.distributions(1);
        assertEq(totalRequired, 100 ether, "totalRequired failed");
        assertEq(totalDeposited, 40 ether, "totalDeposited failed");
        assertEq(totalClaimed, 0 ether, "totalClaimed failed");
    }
}

// --------- case 2: T50 ---------

abstract contract T50_Case2 is NewDistribution_Case2 {

    function setUp() public virtual override {
        super.setUp();
        
        vm.warp(50);

        vm.startPrank(operator);
            uint256 distributionId = 1;
            uint256 newStartTime = 0;
            uint256 newEndTime = 201;
            uint256 newEmissionPerSecond = 2 ether;
            pool.updateDistribution(distributionId, newStartTime, newEndTime, newEmissionPerSecond);
        vm.stopPrank();
    }
}

contract T50_Case2Test is T50_Case2 {

    function test_T50() public {
        DataTypes.Distribution memory distribution = getDistribution(1);       
        // new vars
        assertEq(distribution.emissionPerSecond, 2 ether, "newEmissionPerSecond failed");
        assertEq(distribution.endTime, 201, "newEndTime failed");
        // so far
        assertEq(distribution.lastUpdateTimeStamp, 50, "lastUpdateTimeStamp failed");
        assertEq(distribution.totalEmitted, 50 ether, "totalEmitted failed");

        // get rewardsVault state
        (, , uint256 newTotalRequired, uint256 totalClaimed, uint256 totalDeposited) = rewardsVault.distributions(1);
        assertEq(newTotalRequired, 300 ether, "newTotalRequired failed");
        // old
        assertEq(totalDeposited, 40 ether, "totalDeposited failed");
        assertEq(totalClaimed, 0 ether, "totalClaimed failed");

        //
        uint256 remainingDuration = distribution.endTime - block.timestamp;
        uint256 newDepositable = (remainingDuration * distribution.emissionPerSecond) - totalDeposited;
        assertEq(newDepositable, 310 ether, "newDepositable failed");
    }
}

// ================================================================

// --------- case 3: setup new distribution ---------
abstract contract NewDistribution_Case3 is StateT1_User1StakeAssetsToVault1 {

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(operator);

            uint256 distributionId = 1;
            uint256 distributionStartTime = 1;
            uint256 distributionEndTime = 101;
            uint256 emissionPerSecond = 3 ether;
            uint256 tokenPrecision = 1E18;
            bytes32 tokenAddress = rewardsVault.addressToBytes32(address(rewardsToken1));

        pool.setupDistribution(distributionId, distributionStartTime, distributionEndTime, emissionPerSecond, tokenPrecision, dstEid, tokenAddress); 

        vm.stopPrank();

        // MINT + DEPOSIT
        vm.startPrank(depositor);

            // mint needed
            uint256 totalRequired = (distributionEndTime - distributionStartTime) * emissionPerSecond;
            rewardsToken1.mint(depositor, totalRequired);
            rewardsToken1.approve(address(rewardsVault), totalRequired);
            // deposit
            rewardsVault.deposit(distributionId, 300 ether, depositor);

        vm.stopPrank();
    }
}

contract NewDistribution_Case3Test is NewDistribution_Case3 {

    function test_NewDistribution() public {
        DataTypes.Distribution memory distribution = getDistribution(1);
        assertEq(distribution.lastUpdateTimeStamp, 1);
        
        // get rewardsVault state
        (, , uint256 totalRequired, uint256 totalClaimed, uint256 totalDeposited) = rewardsVault.distributions(1);
        assertEq(totalRequired, 300 ether, "totalRequired failed");
        assertEq(totalDeposited, 300 ether, "totalDeposited failed");
        assertEq(totalClaimed, 0 ether, "totalClaimed failed");
    }
}

// --------- case 3: T50 ---------

abstract contract T50_Case3 is NewDistribution_Case3 {

    function setUp() public virtual override {
        super.setUp();
        
        vm.warp(50);

        vm.startPrank(operator);
            uint256 distributionId = 1;
            uint256 newStartTime = 0;
            uint256 newEndTime = 201;
            uint256 newEmissionPerSecond = 1 ether;
            pool.updateDistribution(distributionId, newStartTime, newEndTime, newEmissionPerSecond);
        vm.stopPrank();
    }
}

contract T50_Case3Test is T50_Case3 {

    function test_T50() public {
        DataTypes.Distribution memory distribution = getDistribution(1);       
        assertEq(distribution.lastUpdateTimeStamp, 50, "lastUpdateTimeStamp failed");
        // new vars
        assertEq(distribution.emissionPerSecond, 1 ether, "newEmissionPerSecond failed");
        assertEq(distribution.endTime, 201, "newEndTime failed");
        assertEq(distribution.totalEmitted, 150 ether, "totalEmitted failed");
        

        // get rewardsVault state
        (, , uint256 newTotalRequired, uint256 totalClaimed, uint256 totalDeposited) = rewardsVault.distributions(1);
        assertEq(newTotalRequired, 150 ether, "newTotalRequired failed");
        assertEq(totalDeposited, 300 ether, "totalDeposited failed");
        
        //
        uint256 remainingDuration = distribution.endTime - block.timestamp;
        uint256 newDepositable = (remainingDuration * distribution.emissionPerSecond) - totalDeposited;
        assertEq(newDepositable, 0 ether, "newDepositable failed");
    }
}