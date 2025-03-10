// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {NftRegistry} from "../../lib/NftLocker/src/NftRegistry.sol";

contract MockRegistry is NftRegistry {


    constructor(address endpoint, address owner, uint32 dstEid) NftRegistry(endpoint, owner, dstEid) {
    }
    
    function register(address user, uint256[] memory tokenIds) public {

        _register(user, tokenIds);
    }
}