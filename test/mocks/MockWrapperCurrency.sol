// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {MockCurrency} from "./MockCurrency.sol";

contract MockWrapperCurrency is MockCurrency {
    constructor(string memory name, string memory symbol) MockCurrency(name, symbol) {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function mint(address to, uint256 amount) external payable override {
        require(msg.value == amount, "MockWrapperCurrency::mint - msg.value != amount");
        _mint(to, amount);
    }

    function mint(uint256 amount) external payable override {
        require(msg.value == amount, "MockWrapperCurrency::mint - msg.value != amount");
        _mint(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool callSucceeded,) = msg.sender.call{value: amount}("");
        require(callSucceeded, "MockWrapperCurrency::withdraw - transfer failed");
    }
}
