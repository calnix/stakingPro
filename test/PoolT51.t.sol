/**

        // user1 claims rewards from vault1
        vm.startPrank(user1);
            pool.claimRewards(vaultId1, 1);
            pool.claimRewards(vaultId2, 1);
        vm.stopPrank();

        // user2 claims rewards from vault1
        vm.startPrank(user2);
            pool.claimRewards(vaultId1, 1);
            pool.claimRewards(vaultId2, 1);
        vm.stopPrank();
 */