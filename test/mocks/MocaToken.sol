// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "./../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MocaToken is ERC20 {

    constructor(string memory name, string memory symbol) ERC20(name, symbol){}

    function mint(address user, uint256 amount) external {
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) external {
        _burn(user, amount);
    }
}