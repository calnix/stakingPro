// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract DataTypes {

    /*//////////////////////////////////////////////////////////////
                                  POOL
    //////////////////////////////////////////////////////////////*/


    struct Vault {
        bytes32 vaultId;   // do i need?
        address creator;
        uint256[] creationTokenIds;     // nfts staked for creation

        uint256 startTime;              // uint40
        uint256 endTime;                // cooldown ends at this time

        // fees: pct values, sum <= 50%
        uint256 nftFeeFactor;
        uint256 creatorFeeFactor;   
        uint256 realmPointsFeeFactor;

        // staked assets
        uint256 stakedNfts;            //2^8 -1 NFTs. uint8
        uint256 stakedTokens;
        uint256 stakedRealmPoints;

        // boosted balances 
        uint256 totalBoost;
        uint256 boostedStakedTokens; 
        uint256 boostedRealmPoints;
    }

    //Note: Each vault has an account for each vaultId
    struct VaultAccount {
        uint256 chainId;    
        bytes32 tokenAddr;  

        // index: reward token
        uint256 poolIndex;             //rewardsAccPerAllocPoint
        uint256 poolNftIndex;          //rewardsAccPerNFT
        uint256 poolRpIndex;           //rewardsAccPerRealmPoint 

        // rewards: reward token | based on allocPoints
        uint256 totalAccRewards;
        uint256 accCreatorRewards;   
        uint256 accNftStakingRewards;            
        uint256 accRealmPointsRewards;

        uint256 rewardsAccPerToken;
        uint256 totalClaimedRewards;    // total: staking, nft, creator, rp
    }

    //note: can consider removing; unless stack issues
    struct Fees {
        // fees: pct values
        uint256 nftFeeFactor;
        uint256 creatorFeeFactor;   
        uint256 realmPointsFeeFactor;
    }


    /*//////////////////////////////////////////////////////////////
                                  USER
    //////////////////////////////////////////////////////////////*/

    struct User {

        // staked assets
        uint256[] tokenIds;     
        uint256 stakedTokens;   
        uint256 stakedRealmPoints;

    }

    struct UserAccount {

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

    /*//////////////////////////////////////////////////////////////
                                 TOKEN
    //////////////////////////////////////////////////////////////*/
        
    struct Distribution {
        //uint256 poolId;

        uint256 chainId;    // dist. moca on base and on eth independently 
        bytes32 tokenAddr;  // LZ: to account for non-evm addr
        uint256 TOKEN_PRECISION;
        
        uint256 endTime;
        uint256 startTime;
        uint256 emissionPerSecond;        

        uint256 index;
        uint256 lastUpdateTimeStamp;  

        // for updating emissions: denominated in reward tokens
        uint256 totalDeposited;       
        uint256 totalWithdrawn;
        uint256 totalEmitted;

        //...claimed?
    }

}