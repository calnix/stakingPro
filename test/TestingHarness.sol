// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2, stdStorage, StdStorage} from "forge-std/Test.sol";

import "../src/StakingPro.sol";
import "../src/RewardsVaultV1.sol";

// mocks
import "../test/mocks/MocaToken.sol";
import "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import { MockRegistry } from "../test/mocks/MockRegistry.sol";
import { EndpointV2Mock } from "./mocks/EndpointV2Mock.sol";

// interfaces
import {IRealmPoints} from "./../src/interfaces/IRealmPoints.sol";

// utils
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";



abstract contract TestingHarness is Test {
    using stdStorage for StdStorage;

    // contracts
    StakingPro public pool;
    RewardsVaultV1 public rewardsVault;
    EndpointV2Mock public lzMock;

    // staking assets
    MocaToken public mocaToken;  
    MockRegistry public nftRegistry;   
    
    // rewards
    ERC20Mock public rewardsToken1;
    ERC20Mock public rewardsToken2;
    ERC20Mock public rewardsToken3;

    // entities
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public owner = makeAddr("owner");
    address public monitor = makeAddr("monitor");   
    address public operator = makeAddr("operator");
    address public depositor = makeAddr("depositor");
    address public deployer = makeAddr("deployer");

    // ------ staking assets ------
    // user moca
    uint256 public user1Moca = 50 ether;
    uint256 public user2Moca = 100 ether;
    uint256 public user3Moca = 150 ether;

    // user nfts
    uint256 public user1Nfts = 5;
    uint256[] public user1NftsArray = new uint256[](user1Nfts);

    uint256 public user2Nfts = 10;
    uint256[] public user2NftsArray = new uint256[](user1Nfts);

    uint256 public user3Nfts = 15;
    uint256[] public user3NftsArray = new uint256[](user1Nfts);

    // user rp
    uint256 public user1Rp = 250;
    uint256 public user2Rp = 500;
    uint256 public user3Rp = 750;

    // ------ stakingPool constructor data ------
    uint256 public startTime = 1;
    uint256 public nftMultiplier = 1000;
    uint256 public creationNftsRequired = 5;
    uint256 public vaultCoolDownDuration = 1 days;

    // ecdsa
    address public storedSigner;
    uint256 public storedSignerPrivateKey;
    
    // LZ
    uint32 public dstEid = 1;

    function setUp() public virtual {
        // starting point: T0
        vm.warp(0 days); 
        vm.startPrank(deployer);

        // address endpoint, address owner, address pool, uint32 dstEid
        lzMock = new EndpointV2Mock();
        nftRegistry = new MockRegistry(address(lzMock), owner, address(pool), dstEid);

        // mocaToken
        mocaToken = new MocaToken("MocaToken", "MOCA");   

        // signer
        (storedSigner, storedSignerPrivateKey) = makeAddrAndKey("storedSigner");

        pool = new StakingPro(
            address(nftRegistry),
            address(mocaToken), 
            startTime,
            nftMultiplier,
            creationNftsRequired,
            vaultCoolDownDuration,
            owner,
            monitor,
            operator,
            storedSigner,
            "StakingPro",
            "1");

        // address moneyManager, address monitor, address owner, address pool
        rewardsVault = new RewardsVaultV1(owner, owner, owner, address(pool));

        // rewards
        rewardsToken1 = new ERC20Mock();
        rewardsToken2 = new ERC20Mock();
        rewardsToken3 = new ERC20Mock();

        // mint moca
        mocaToken.mint(user1, user1Moca);
        mocaToken.mint(user2, user2Moca);
        mocaToken.mint(user3, user3Moca);

        // register nfts
        for (uint256 i = 0; i < user1Nfts; ++i) {
            // [0, 1, 2, 3, 4]
            user1NftsArray[i] = i;
        }
        nftRegistry.register(user1, user1NftsArray);

        for (uint256 i = user1Nfts; i < user2Nfts; ++i) {
            // [5, 6, 7, 8, 9]
            user2NftsArray[i-user1Nfts] = i;
        }
        nftRegistry.register(user2, user2NftsArray);

        for (uint256 i = user2Nfts; i < user3Nfts; ++i) {
            // [10, 11, 12, 13, 14]
            user3NftsArray[i-user2Nfts] = i;
        }
        nftRegistry.register(user3, user3NftsArray);

        vm.stopPrank();

        // 
        vm.prank(owner);
        nftRegistry.setPool(address(pool));
    }

    function generateSignature(address user, bytes32 vaultId, uint256 amount, uint256 expiry, uint256 nonce) public returns (bytes memory) {
        // Pack the struct data
        bytes32 structHash = keccak256(
            abi.encode(
                pool.TYPEHASH(),
                user,
                vaultId,
                amount,
                expiry,
                nonce
            )
        );
        
        // Get the digest using the contract's domain separator
        bytes32 digest = pool.hashTypedDataV4(structHash);
        
        // Sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(storedSignerPrivateKey, digest);
        
        // Return the signature in the correct format
        return abi.encodePacked(r, s, v);
    }

        ///@dev Generate a vaultId. keccak256 is cheaper than using a counter with a SSTORE, even accounting for eventual collision retries.
    function generateVaultId(uint256 salt, address user) public view returns (bytes32) {
        return bytes32(keccak256(abi.encode(user, block.timestamp, salt)));
    }
}

