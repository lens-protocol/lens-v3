// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

contract ZkTest is Test {
    function isZkEvm() public view returns (bool) {
        return block.coinbase == address(0x8001);
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
