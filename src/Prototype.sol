
library PoolLogic {

    function executeStake() external returns (uint256) {
        return 1;
    }
}

contract Pool {
 
    uint256 public state;

    function stake() external {

        state = PoolLogic.executeStake();
    } 
}