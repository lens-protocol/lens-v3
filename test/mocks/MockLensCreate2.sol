// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

contract MockLensCreate2 {
    function testMockLensCreate2() public {
        // Prevents being included in the foundry coverage report
    }

    mapping(bytes32 => address) public addresses;

    function getAddress(bytes32 salt) public view returns (address) {
        return addresses[salt];
    }

    function setAddress(bytes32 salt, address addr) public {
        addresses[salt] = addr;
    }
}
