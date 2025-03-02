// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT6.t.sol";


//note: 5 seconds delta. another 5 ether of staking power emitted @1ether/second
abstract contract StateT11_Distribution1Created is StateT6_User2StakeAssetsToVault1 {

    function setUp() public virtual override {
        super.setUp();

        // T11   
        vm.warp(11);

        // distribution params
        uint256 distributionId = 1;
        uint256 distributionStartTime = 21;
        uint256 distributionEndTime = 21 + 2 days;
        uint256 emissionPerSecond = 1 ether;
        uint256 tokenPrecision = 1E18;
        bytes32 tokenAddress = rewardsVault.addressToBytes32(address(rewardsToken1));
        uint256 totalRequired = 2 days * emissionPerSecond;

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

        assertEq(distribution.endTime, 21 + 2 days);
        assertEq(distribution.startTime, 21);
        assertEq(distribution.emissionPerSecond, 1 ether);

        assertEq(distribution.index, 0);
        assertEq(distribution.totalEmitted, 0);
        assertEq(distribution.lastUpdateTimeStamp, 21);
        
        assertEq(distribution.manuallyEnded, 0);
    }
}
