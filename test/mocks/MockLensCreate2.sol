// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

contract MockLensCreate2 {
    mapping(bytes32 => address) public addresses;

    function getAddress(bytes32 salt) public view returns (address) {
        return addresses[salt];
    }

    function setAddress(bytes32 salt, address addr) public {
        addresses[salt] = addr;
    }
}
