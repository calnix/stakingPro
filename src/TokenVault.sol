// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;




contract TokenVault {

    
    struct TokenData {
        uint256 startTime;
        uint256 endTime;
        uint256 emissionPerSecond;
        //...
        uint256 tokenIndex;
        //..
        uint256 totalDeposited;
        uint256 totalClaimed;
    }

    struct VaultData {}
    struct UserInfo {}

    mapping(address token => TokenData tokenData) public tokens;

    mapping(address token => VaultData vaultData) public vaults;

    mapping(address token => UserInfo userData) public users;




    function _updatePoolIndex() internal returns (DataTypes.PoolAccounting memory, uint256) {
        // cache
        DataTypes.PoolAccounting memory pool_ = pool;
        
        // already updated: return
        if(block.timestamp == pool_.lastUpdateTimeStamp) {
            return (pool_, pool_.lastUpdateTimeStamp);
        }
        
        // totalBalance = totalAllocPoints (boosted balances)
        (uint256 nextPoolIndex, uint256 currentTimestamp, uint256 emittedRewards) = _calculatePoolIndex(pool_.index, pool_.emissisonPerSecond, pool_.lastUpdateTimeStamp, pool.totalAllocPoints);

        if(nextPoolIndex != pool_.index) {
            
            // prev timestamp, oldIndex, newIndex: emit prev timestamp since you know the currentTimestamp as per txn time
            emit PoolIndexUpdated(pool_.lastUpdateTimeStamp, pool_.index, nextPoolIndex);

            pool_.index = nextPoolIndex;
            pool_.rewardsEmitted += emittedRewards; 
            pool_.lastUpdateTimeStamp = block.timestamp;
        }

        // update storage
        pool = pool_;

        return (pool_, currentTimestamp);
    }

    function _calculatePoolIndex(uint256 currentPoolIndex, uint256 emissionPerSecond, uint256 lastUpdateTimestamp, uint256 totalBalance) internal view returns (uint256, uint256, uint256) {
        if (
            emissionPerSecond == 0                           // 0 emissions. no rewards setup. 
            || totalBalance == 0                             // nothing has been staked
            || lastUpdateTimestamp == block.timestamp        // assetIndex already updated
            || lastUpdateTimestamp > endTime                 // distribution has ended
        ) {

            return (currentPoolIndex, lastUpdateTimestamp, 0);                       
        }

        uint256 currentTimestamp = block.timestamp > endTime ? endTime : block.timestamp;
        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;
        
        uint256 emittedRewards = emissionPerSecond * timeDelta;

        uint256 nextPoolIndex = ((emittedRewards * TOKEN_PRECISION) / totalBalance) + currentPoolIndex;
    
        return (nextPoolIndex, currentTimestamp, emittedRewards);
    }

} 
    