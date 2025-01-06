// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract DataTypes {

    /*//////////////////////////////////////////////////////////////
                                  POOL
    //////////////////////////////////////////////////////////////*/


    struct Vault {
        address creator;
        uint256[] creationTokenIds;     // nfts staked for creation

        uint256 startTime;              // uint40
        uint256 endTime;                // cooldown ends at this time
        uint256 removed;                // flag to indicate if vault has been removed

        // fees: pct values, sum <= 50%
        // fee factors are expressed as w/ 1e18 precision
        uint256 nftFeeFactor;
        uint256 creatorFeeFactor;   
        uint256 realmPointsFeeFactor;

        // staked assets
        uint256 stakedNfts;            //2^8 -1 NFTs. uint8
        uint256 stakedTokens;
        uint256 stakedRealmPoints;

        // boosted balances 
        uint256 totalBoostFactor;   // no. of nfts * nftBoostFactor | 1.XXX
        uint256 boostedRealmPoints;
        uint256 boostedStakedTokens; 
    }

    //Note: Each vault has an account for each distribution
    struct VaultAccount {
        uint256 chainId;    
        bytes32 tokenAddr;  

        // index: reward token
        uint256 index;             //rewardsAccPerAllocPoint
        uint256 nftIndex;          //rewardsAccPerNFT
        uint256 rpIndex;           //rewardsAccPerRealmPoint 

        // rewards: reward token | based on allocPoints
        uint256 totalAccRewards;
        uint256 accCreatorRewards;   
        uint256 accNftStakingRewards;            
        uint256 accRealmPointsRewards;

        uint256 rewardsAccPerUnitStaked;    // rewardsAccPerUnitStaked: per unit rp or staked moca
        uint256 totalClaimedRewards;        // total: staking, nft, creator, rp
    }

    /*//////////////////////////////////////////////////////////////
                                  USER
    //////////////////////////////////////////////////////////////*/

    struct User {

        // onboarded RP
        uint256 realmPoints;

        // staked assets
        uint256[] tokenIds;     
        uint256 stakedTokens;   
        uint256 stakedRealmPoints;
    }

    struct UserAccount {

        // indexes: precision is based on reward tokens
        uint256 index; 
        uint256 nftIndex;
        uint256 rpIndex;           

        //rewards: from staking MOCA; less of fees
        uint256 accStakingRewards;          // receivable      
        uint256 claimedStakingRewards;      // received

        //rewards: NFTs
        uint256 accNftStakingRewards; 
        uint256 claimedNftRewards;

        //rewards: RP
        uint256 accRealmPointsRewards; 
        uint256 claimedRealmPointsRewards;

        //rewards: creatorFees
        uint256 claimedCreatorRewards;
    }

    /*//////////////////////////////////////////////////////////////
                                 TOKEN
    //////////////////////////////////////////////////////////////*/
        
    struct Distribution {
        uint256 distributionId; //0 for staking power
        uint256 TOKEN_PRECISION; // cannot be 0. min 1e0

        uint256 endTime;
        uint256 startTime;
        uint256 emissionPerSecond;        

        uint256 index;
        uint256 totalEmitted;
        uint256 lastUpdateTimeStamp;  

        // state
        uint256 manuallyEnded;
    }

    /*//////////////////////////////////////////////////////////////
                                INPUTS 
    //////////////////////////////////////////////////////////////*/


    struct ExecuteStakeTokensParams {
        address user;
        uint256 amount;
        bytes32 vaultId;
        
        uint256 totalBoostedRealmPoints;
        uint256 totalBoostedStakedTokens;

        uint256 PRECISION_BASE;
    }


}