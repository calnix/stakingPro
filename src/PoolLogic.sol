// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import './Events.sol';
import {Errors} from './Errors.sol';
import {DataTypes} from './DataTypes.sol';

import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

library PoolLogic {
    using SafeERC20 for IERC20;


    function executeCreateVault(
        //mapping(address => DataTypes.ReserveData) storage reservesData,
        //mapping(uint256 => address) storage reservesList,
        //DataTypes.UserConfigurationMap storage userConfig,

        uint256[] memory tokenIds,
        DataTypes.Fees calldata fe1es
    ) external {

    }

}
