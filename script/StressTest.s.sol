// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {StakingPro} from "../src/StakingPro.sol";

import {RewardsVaultV1} from "../src/RewardsVaultV1.sol";

// mocks
import {MockRegistry} from "./../test/mocks/MockRegistry.sol";
import {ERC20Mock} from "./../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

// interface
import {IERC20} from "./../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// base sepolia
abstract contract Contracts is Script {
    
    // staking assets
    ERC20Mock public mockMoca;
    MockRegistry public mockRegistry;
    
    // staking assets
    StakingPro public pool; 
    RewardsVaultV1 public rewardsVault;

    // rewards assets
    ERC20Mock public rewardToken;

    address public deployer = 0x8C9C001F821c04513616fd7962B2D8c62f925fD2;

    modifier broadcast_TestKey() {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST");
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }
}

contract DeployContracts is Contracts {
    
    function run() public broadcast_TestKey {
        
        // staking assets
        mockMoca = new ERC20Mock();
        
            uint16 baseSepoliaID = 40245;
            address baseSepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;
        mockRegistry = new MockRegistry(address(baseSepoliaEP), deployer, address(pool), baseSepoliaID);

        // constructor params
        address stakedToken = address(mockMoca);
        address registry = address(mockRegistry);       
        uint256 startTime = block.timestamp + 5 minutes;
        uint256 nftMultiplier = 1000; // 10% boost
        uint256 creationNftsRequired = 5;
        uint256 vaultCoolDownDuration = 7 days;
        address owner = deployer;
        address storedSigner = deployer;

        pool = new StakingPro(registry, stakedToken, startTime,
            nftMultiplier, creationNftsRequired, vaultCoolDownDuration,
            owner, owner, storedSigner,
            "StakingPro", "1"
        );

        rewardsVault = new RewardsVaultV1(deployer, owner, owner, address(pool));

        // connect pool and rewardsVault
        pool.setRewardsVault(address(rewardsVault));

        // setup distribution 0: staking power
        pool.setupDistribution(
            0,
            startTime,
            0,
            1e18,
            1E18,
            0,
            bytes32(0)
        );
        
        // --------- DONE: contracts deployed + staking power setup ---------

        // setup requirements for vault creation + staking
        uint256[] memory tokenIds = new uint256[](5);
            tokenIds[0] = 0;
            tokenIds[1] = 1;
            tokenIds[2] = 2;
            tokenIds[3] = 3;
            tokenIds[4] = 4;
        uint256 totalMocaAvailable = 9000 ether;    

        // mint moca + register nfts
        mockMoca.mint(deployer, totalMocaAvailable);
        mockMoca.approve(address(pool), totalMocaAvailable);
        mockRegistry.register(deployer, tokenIds);

        // rewards: each token distribution is 90 ether; 9000 for 100 distributions
        rewardToken = new ERC20Mock();
        rewardToken.mint(deployer, 9000 ether);
        rewardToken.approve(address(rewardsVault), 9000 ether);

        console.log("Deployed MockMoca at:", address(mockMoca));
        console.log("Deployed MockRegistry at:", address(mockRegistry));
        console.log("Deployed StakingPro at:", address(pool));
        console.log("Deployed RewardsVault at:", address(rewardsVault));
        console.log("Deployed RewardToken at:", address(rewardToken));
    }
}

// forge script script/StressTest.s.sol:DeployContracts --rpc-url base_sepolia --broadcast --verify -vvvvv --etherscan-api-key base_sepolia


abstract contract DeployedContracts is Script {

    // staking assets
    ERC20Mock public mockMoca = ERC20Mock(0x9fa21d97DC3251b27D7a27250AFE3D17E7c54400);
    MockRegistry public mockRegistry = MockRegistry(0x902981DD2999638Ba02557B64E3592834D674458);
    
    // staking assets
    StakingPro public pool = StakingPro(0x2b3dC91EBfa167470B25f49Ec6DB8b7052cA423D); 
    RewardsVaultV1 public rewardsVault = RewardsVaultV1(0x685D117D88cE4B1104dc35f935Dd233733E182DB);

    // rewards assets
    ERC20Mock public rewardToken = ERC20Mock(0x60Ea1BEBD8eac57C4c0ed0A16FC6735cBB72ae2C);

    // VAULT ID
    bytes32 public vaultId;

    address public deployer = 0x8C9C001F821c04513616fd7962B2D8c62f925fD2;

    modifier broadcast_TestKey() {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST");
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }
}

contract CreateVault is DeployedContracts {

    function run() public broadcast_TestKey {
        uint256[] memory tokenIds = new uint256[](5);
            tokenIds[0] = 0;
            tokenIds[1] = 1;
            tokenIds[2] = 2;
            tokenIds[3] = 3;
            tokenIds[4] = 4;
        pool.createVault(tokenIds, 1000, 1000, 1000);
    }
}

// forge script script/StressTest.s.sol:CreateVault --rpc-url base_sepolia --broadcast --verify -vvvvv --etherscan-api-key base_sepolia
    /**
        Increment number of distributions setup.
        For each increment, gas profile select user functions till exhaustion.
     */

contract SetupDistributions is DeployedContracts {

    function addressToBytes32(address addr) public pure returns(bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 bytes32_) public pure returns(address) {
        return address(uint160(uint256(bytes32_)));
    }

    function setupDistributionAndDeposit() public returns (uint256) {
        // get next distribution id
        uint256 distributionId = pool.getActiveDistributionsLength();

        // generic distribution params
        uint256 duration = 90 days;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        uint256 totalRewards = 90 ether;
        uint256 emissionPerSecond = 1 ether; // 90 / 90 days = 1 ether per day

        pool.setupDistribution(
            distributionId,
            startTime,
            endTime,
            emissionPerSecond,
            1E18,
            30184,              // BASE EID
            bytes32(uint256(uint160(address(rewardToken))))
        );

        // deposit rewards
        rewardsVault.deposit(distributionId, totalRewards, deployer);

        return distributionId;
    }

    function stakeTokens() public {    
        pool.stakeTokens(vaultId, 90 ether);
    }

    function run() public broadcast_TestKey {

//        while (true) {
            uint256 distributionId = setupDistributionAndDeposit();    
            console.log("Distribution setup ID:", distributionId);

            stakeTokens();
            console.log("Tokens staked");
//        }
    }
}

// forge script script/StressTest.s.sol:StressTest --rpc-url base_sepolia --broadcast --verify -vvvvv --etherscan-api-key base_sepolia
