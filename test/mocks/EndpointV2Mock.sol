// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { MockRegistry } from "./MockRegistry.sol";
import {Test, console2, stdStorage, StdStorage} from "forge-std/Test.sol";

import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { MessagingParams, MessagingFee, MessagingReceipt, IMessageLibManager, ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract EndpointV2Mock is Test {

    // option values for NftLocker::lock()
    bytes public locker_oneTokenId = hex'0003010011010000000000000000000000000000caee';    // 51_950
    bytes public locker_twoTokenId = hex'000301001101000000000000000000000000000132d6';    // 78_550
    bytes public locker_threeTokenId = hex'00030100110100000000000000000000000000019abe';  // 105_150
    bytes public locker_fourTokenId = hex'000301001101000000000000000000000000000202a6';   // 131_750
    bytes public locker_fiveTokenId = hex'00030100110100000000000000000000000000026a8e';   // 158_350

    // option values for NftRegistry::release()
    bytes public registry_oneTokenId = hex'00030100110100000000000000000000000000011d28';    // 73_000
    bytes public registry_twoTokenId = hex'0003010011010000000000000000000000000001650b';    // 91_403
    bytes public registry_threeTokenId = hex'0003010011010000000000000000000000000001acee';  // 109_806
    bytes public registry_fourTokenId = hex'0003010011010000000000000000000000000001f4d1';   // 128_209
    bytes public registry_fiveTokenId = hex'00030100110100000000000000000000000000023cb4';   // 146_612


    function setDelegate(address /*_delegate*/) external {}

    function send(MessagingParams memory messagingParams, address _refundAddress) external payable returns (MessagingReceipt memory) {
        MessagingReceipt memory receipt;
        return receipt;
    }

    /**
    quote calculates gas needed based on payload and options
        - options det. gas allocated for execution on dstChain
        - payload det. gas needed for the data transmission 
    we only focus on the gas needed for payload in this mock
     */
    function quote(MessagingParams memory messagingParams, address) public view returns (uint256, uint256) {
        // 0.1 native fee, 0 lzToken fee
        return (0.1 ether, 0);
    }
}