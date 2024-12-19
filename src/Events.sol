// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DataTypes} from './DataTypes.sol';

event VaultCreated(address indexed creator, uint256 indexed vaultId);


event VaultIndexUpdated(uint256 indexed vaultId, uint256 indexed vaultIndex, uint256 indexed vaultAccruedRewards);




event PoolIndexUpdated(uint256 indexed lastUpdateTimestamp, uint256 indexed oldIndex, uint256 indexed newIndex);
event VaultMultiplierUpdated(uint256 indexed vaultId, uint256 indexed oldMultiplier, uint256 indexed newMultiplier);

event UserIndexesUpdated(address indexed user, uint256 indexed vaultId, uint256 userIndex, uint256 userNftIndex, uint256 userAccruedRewards);

event StakedMoca(address indexed onBehalfOf, uint256 indexed vaultId, uint256 amount);
event StakedMocaNft(address indexed onBehalfOf, uint256 indexed vaultId, uint256[] indexed tokenIds);
event UnstakedMoca(address indexed onBehalfOf, uint256 indexed vaultId, uint256 amount);
event UnstakedMocaNft(address indexed onBehalfOf, uint256 indexed vaultId, uint256[] indexed tokenIds);

event RewardsAccrued(address indexed user, uint256 amount);
event NftRewardsAccrued(address indexed user, uint256 amount);

event RewardsClaimed(uint256 indexed vaultId, address indexed user, uint256 amount);
event NftRewardsClaimed(uint256 indexed vaultId, address indexed creator, uint256 amount);
event CreatorRewardsClaimed(uint256 indexed vaultId, address indexed creator, uint256 amount);

event CreatorFeeFactorUpdated(uint256 indexed vaultId, uint256 indexed oldCreatorFeeFactor, uint256 indexed newCreatorFeeFactor);
event NftFeeFactorUpdated(uint256 indexed vaultId, uint256 indexed oldCreatorFeeFactor, uint256 indexed newCreatorFeeFactor);

event RecoveredTokens(address indexed token, address indexed target, uint256 indexed amount);
event PoolFrozen(uint256 indexed timestamp);

event VaultStakingLimitIncreased(uint256 indexed vaultId, uint256 oldStakingLimit, uint256 indexed newStakingLimit);
event VaultCooldownDurationUpdated(uint256 oldDuration, uint256 newDuration);

event CreationNftRequirementUpdated(uint256 oldRequirement, uint256 newRequirement);

event DistributionCreated(uint256 indexed distributionId, uint256 startTime, uint256 endTime, uint256 emissionPerSecond, uint256 tokenPrecision);
event DistributionEnded(uint256 indexed distributionId, uint256 startTime, uint256 oriendTime);
event DistributionUpdated(uint256 indexed distributionId, uint256 startTime, uint256 endTime, uint256 emissionPerSecond);


event RewardsVaultSet(address oldRewardsVault, address newRewardsVault);