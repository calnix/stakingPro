/**
        // Vault1 fees - user1 reduces creator fee, increases nft and rp fees
        uint256 creatorFeeFactor1 = 500; // Reduced from 1000
        uint256 nftFeeFactor1 = 1250;
        uint256 realmPointsFeeFactor1 = 1250;

        vm.startPrank(user1);
            pool.updateVaultFees(vaultId1, nftFeeFactor1, creatorFeeFactor1, realmPointsFeeFactor1);
        vm.stopPrank();

        // Vault2 fees - user2 reduces creator fee, increases nft and rp fees
        uint256 creatorFeeFactor2 = 250; // Reduced from 500
        uint256 nftFeeFactor2 = 1125;
        uint256 realmPointsFeeFactor2 = 625;

        vm.startPrank(user2);
            pool.updateVaultFees(vaultId2, nftFeeFactor2, creatorFeeFactor2, realmPointsFeeFactor2);
        vm.stopPrank();
 */