// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWrapperCurrency is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool callSucceeded,) = msg.sender.call{value: amount}("");
        require(callSucceeded, "MockWrapperCurrency::withdraw - transfer failed");
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
