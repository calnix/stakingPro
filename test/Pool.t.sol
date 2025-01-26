// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {TestingHarness} from "./TestingHarness.sol";

abstract contract StateDeploy is TestingHarness {    

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
    }

    function testUserCannotClaim() public {

    }
}
