// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./PoolT56.t.sol";

abstract contract StateT61_Vault2CooldownActivated_UpdatedCooldown is StateT56_UsersClaimRewardsFromBothVaults {

    // for reference
    DataTypes.Vault vault1_T61; 
    DataTypes.Vault vault2_T61;

    DataTypes.Distribution distribution0_T61;
    DataTypes.Distribution distribution1_T61;
    //vault1
    DataTypes.VaultAccount vault1Account0_T61;
    DataTypes.VaultAccount vault1Account1_T61;
    //vault2
    DataTypes.VaultAccount vault2Account0_T61;
    DataTypes.VaultAccount vault2Account1_T61;
    //user1+vault1
    DataTypes.UserAccount user1Vault1Account0_T61;
    DataTypes.UserAccount user1Vault1Account1_T61;
    //user2+vault1
    DataTypes.UserAccount user2Vault1Account0_T61;
    DataTypes.UserAccount user2Vault1Account1_T61;
    //user1+vault2
    DataTypes.UserAccount user1Vault2Account0_T61;
    DataTypes.UserAccount user1Vault2Account1_T61;
    //user2+vault2
    DataTypes.UserAccount user2Vault2Account0_T61;
    DataTypes.UserAccount user2Vault2Account1_T61;

    function setUp() public virtual override {
        super.setUp();

        vm.warp(61);
        
        vm.startPrank(operator);
            pool.updateVaultCooldown(5);
        vm.stopPrank();

        vm.startPrank(user2);
            pool.activateCooldown(vaultId2);
        vm.stopPrank();

        // save state
        vault1_T61 = pool.getVault(vaultId1);
        vault2_T61 = pool.getVault(vaultId2);
        
        distribution0_T61 = getDistribution(0); 
        distribution1_T61 = getDistribution(1);

        vault1Account0_T61 = getVaultAccount(vaultId1, 0);
        vault1Account1_T61 = getVaultAccount(vaultId1, 1);  
        vault2Account0_T61 = getVaultAccount(vaultId2, 0);
        vault2Account1_T61 = getVaultAccount(vaultId2, 1);

        user1Vault1Account0_T61 = getUserAccount(user1, vaultId1, 0);
        user1Vault1Account1_T61 = getUserAccount(user1, vaultId1, 1);
        user2Vault1Account0_T61 = getUserAccount(user2, vaultId1, 0);
        user2Vault1Account1_T61 = getUserAccount(user2, vaultId1, 1);
        user1Vault2Account0_T61 = getUserAccount(user1, vaultId2, 0);
        user1Vault2Account1_T61 = getUserAccount(user1, vaultId2, 1);
        user2Vault2Account0_T61 = getUserAccount(user2, vaultId2, 0);
        user2Vault2Account1_T61 = getUserAccount(user2, vaultId2, 1);
    }
}



contract StateT61p_UpdateVaultCooldownTest is StateT61_Vault2CooldownActivated_UpdatedCooldown {

    function testVaultEndTimeUpdatedWithNewCooldown() public {
        // Get vault after cooldown update
        DataTypes.Vault memory vault = pool.getVault(vaultId2);

        assertEq(vault.endTime, 61 + 5, "Vault endTime not updated with new cooldown");
    }
}


