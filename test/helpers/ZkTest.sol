// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

contract ZkTester {
    function testZkTester() public {
        // Prevents being included in the foundry coverage report
    }

    function isZkEvm() public view returns (bool) {
        return block.coinbase == address(0x8001);
    }
}

contract ZkTest is Test {
    function testZkTest() public {
        // Prevents being included in the foundry coverage report
    }

    function isZkEvm() public returns (bool) {
        ZkTester zkTester = new ZkTester();
        return zkTester.isZkEvm();
    }

    modifier onlyZkEvm() {
        vm.skip(!isZkEvm());
        _;
    }

    modifier onlyEvm() {
        vm.skip(isZkEvm());
        _;
    }
}
