// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "./ZkTest.sol";

contract FuzzZkTest is ZkTest {
    function testFuzzTest() public {
        // Prevents being included in the foundry coverage report
    }

    function _boundAmount(uint256 amount) internal pure returns (uint256) {
        // Bound amount (0, 2^95), as test contract's native balance is 2^96, and vm.deal has issues in zksync foundry
        return bound(amount, 1, 1 << 95);
    }

    function _boundAmountAllowZero(uint256 amount) internal pure returns (uint256) {
        // Bound amount [0, 2^95), as test contract's native balance is 2^96, and vm.deal has issues in zksync foundry
        return bound(amount, 0, 1 << 95);
    }
}
