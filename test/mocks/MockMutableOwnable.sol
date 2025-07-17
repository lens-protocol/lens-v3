// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

contract MockMutableOwnable {
    address immutable _initialOwner;
    address internal _mockedOwner;

    constructor(address initialOwner) {
        _initialOwner = initialOwner;
    }

    function owner() external view returns (address) {
        return _mockedOwner == address(0) ? _initialOwner : _mockedOwner;
    }

    function mockOwner(address newOwner) external {
        _mockedOwner = newOwner;
    }
}
