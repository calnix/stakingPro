// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract DataTypes {

    /*//////////////////////////////////////////////////////////////
                                  POOL
    //////////////////////////////////////////////////////////////*/

    struct PoolAccounting {
        // rewards: x
        uint256 totalAllocPoints;                // totalBalanceBoosted
        uint256 emissisonPerSecond;           
    
        // rewards: y
        uint256 index;                       // rewardsAccPerAllocPoint (to date) || rewards are booked into index
        uint256 lastUpdateTimeStamp;  
        
        // for updating emissions: denominated in reward tokens
        uint256 totalStakingRewards;       
        uint256 rewardsEmitted;            // prevent ddos rewards vault

        // staked assets
        //uint256 totalStakedTokens;
        //uint256 totalStakedNfts;
        //uint256 totalStakedRealmPoints;
    }

    /*//////////////////////////////////////////////////////////////
                                 VAULT
    //////////////////////////////////////////////////////////////*/


    struct Vault {
        bytes32 vaultId;   
        address creator;
        uint256 startTime;             // uint40
        uint256[] creationTokenIds;     // nfts staked for creation

        
        // note: applicable to staked tokens
        uint256 multiplier;
        uint256 allocPoints; 

        // staked assets
        uint256 stakedNfts;            //2^8 -1 NFTs. uint8
        uint256 stakedTokens;
        uint256 stakedRealmPoints;
        
        // rewards
        VaultAccounting accounting;
    }

    struct VaultAccounting {
        // index: reward token
        uint256 vaultIndex;             //rewardsAccPerAllocPoint
        uint256 vaultNftIndex;          //rewardsAccPerNFT
        uint256 vaultRpIndex;           //rewardsAccPerRealmPoint 

        // fees: pct values, with 18dp precision
        Fees rewardTokenFees;
        Fees stakingPowerFees;

        // rewards: reward token | based on allocPoints
        uint256 totalAccRewards;
        uint256 accCreatorRewards;   
        uint256 accNftStakingRewards;            
        uint256 accRealmPointsRewards;

        uint256 rewardsAccPerToken;
        uint256 totalClaimedRewards;    // total: staking, nft, creator
    }

    struct Fees {
        // fees: pct values, with 18dp precision
        uint256 nftFeeFactor;
        uint256 creatorFeeFactor;   
        uint256 realmPointFeeFactor;
    }


    /*//////////////////////////////////////////////////////////////
                                  USER
    //////////////////////////////////////////////////////////////*/

    struct UserInfo {

        // staked assets
        uint256[] tokenIds;     // nfts staked: array.length < 4
        uint256 stakedTokens;   
        uint256 stakedRealmPoints;   

        // indexes: based on reward tokens
        uint256 userIndex; 
        uint256 userNftIndex;

        //rewards: tokens (from staking tokens less of fees)
        uint256 accStakingRewards;          // receivable      
        uint256 claimedStakingRewards;      // received

        //rewards: NFTs
        uint256 accNftStakingRewards; 
        uint256 claimedNftRewards;

        //rewards: creatorFees
        uint256 claimedCreatorRewards;
    }
}