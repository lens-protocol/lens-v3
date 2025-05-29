// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Ownable} from "contracts/core/access/Ownable.sol";
import {MockUniversal} from "test/mocks/MockUniversal.sol";

contract MockOwnableUniversal is MockUniversal, Ownable {
    function testMockOwnableUniversal() public {
        // Prevents being included in the foundry coverage report
    }

    function mockOwner(address newOwner) external {
        _transferOwnership(newOwner);
    }
}
