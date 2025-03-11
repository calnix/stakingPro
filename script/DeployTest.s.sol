// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {StakingPro} from "../src/StakingPro.sol";
import {RewardsVaultV1} from "../src/RewardsVaultV1.sol";
import {NftRegistry} from "./../lib/NftLocker/src/NftRegistry.sol";

// mocks
import {ERC20Mock} from "./../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "./../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DeployTest is Script {
    StakingPro public pool;
    RewardsVaultV1 public rewardsVault;

    ERC20Mock public mockToken;

    function setUp() public {}

    function addressToBytes32(address addr) public pure returns(bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 bytes32_) public pure returns(address) {
        return address(uint160(uint256(bytes32_)));
    }

    function run() public {
        console.log("Deploying StakingPro...");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST");
        vm.startBroadcast(deployerPrivateKey);
        
        // constructor params
        address registry = 0x284C14ba977714f4d1904f6C65e4e5a4c27696C2;
        address stakedToken = 0x03946287b52B88C8357E813fbA3F472c60FaE727;
        
        // Set start time to 24 hours in the future
        uint256 startTime_ = block.timestamp + 10;
        uint256 nftMultiplier = 1000; // 10% boost
        uint256 creationNftsRequired = 5;
        uint256 vaultCoolDownDuration = 7 days;
        address owner = 0x8C9C001F821c04513616fd7962B2D8c62f925fD2;
        address storedSigner;
        uint256 storedSignerPrivateKey;

        // .... deploy contracts ....

        // signer
        (storedSigner, storedSignerPrivateKey) = makeAddrAndKey("storedSigner");
        console.log("Stored signer:", storedSigner);
        console.log("Stored signer private key:", storedSignerPrivateKey);

        pool = new StakingPro(
            registry,
            stakedToken, 
            startTime_,
            nftMultiplier,
            creationNftsRequired,
            vaultCoolDownDuration,
            owner,
            owner,
            owner,
            storedSigner,
            "StakingPro",
            "1"
        );

        rewardsVault = new RewardsVaultV1(
            owner,
            owner,
            owner,
            address(pool)
        );

        console.log("Deployed StakingPro at:", address(pool));
        console.log("Deployed RewardsVault at:", address(rewardsVault));

        // connect pool and rewardsVault
        pool.setRewardsVault(address(rewardsVault));
        NftRegistry(registry).setPool(address(pool));

        // setup distribution
        pool.setupDistribution(
            0,
            startTime_,
            0,
            1e18,
            1E18,
            0,
            bytes32(0)
        );

        vm.stopBroadcast();
    }
}

// forge script script/DeployTest.s.sol:DeployTest --rpc-url base_sepolia --broadcast --verify -vvvvv --etherscan-api-key base_sepolia


contract SetupD1 is Script {
    ERC20Mock public mockToken;

    address public owner = 0x8C9C001F821c04513616fd7962B2D8c62f925fD2;
    StakingPro public pool = StakingPro(0x4902da6825D1E77eFaCecAaD764c74b01100E4A7);
    RewardsVaultV1 public rewardsVault = RewardsVaultV1(0xfE5F4B9d510C80EA13Ecf4be9B9Df00FA9bD28D4);

    function run() public {
        console.log("Setting up distribution 1...");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST");
        vm.startBroadcast(deployerPrivateKey);

        // get pool start time
        uint256 poolStartTime = pool.startTime();

        // distribution 1
        uint256 duration = 90 days;
        uint256 startTime = poolStartTime > block.timestamp ? poolStartTime : block.timestamp + 200;
        uint256 endTime = startTime + duration;

        uint256 totalRewards = 90 ether;
        uint256 emissionPerSecond = 1 ether; // 90 / 90 days = 1 ether per day

        // mock token
        mockToken = new ERC20Mock();
        mockToken.mint(owner, totalRewards);
        mockToken.approve(address(rewardsVault), totalRewards);

        // setup distribution
        pool.setupDistribution(
            1,
            startTime,
            endTime,
            emissionPerSecond,
            1E18,
            30184,              // BASE EID
            bytes32(uint256(uint160(address(mockToken))))
        );

        // deposit rewards
        rewardsVault.deposit(1, totalRewards, owner);
        
        vm.stopBroadcast();
    }
}

// forge script script/DeployTest.s.sol:SetupD1 --rpc-url base_sepolia --broadcast --verify -vvvvv --etherscan-api-key base_sepolia
