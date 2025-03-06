// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Initializable} from "@core/upgradeability/Initializable.sol";
import {Errors} from "@core/types/Errors.sol";

contract InitializableContract is Initializable {
    function testInitializableContract() public {
        // Prevents being included in the foundry coverage report
    }

    function initialize() public initializer {
        return;
    }
}

contract InitializableTest is Test {
    /// @custom:keccak lens.storage.Initializable
    bytes32 constant STORAGE__INITIALIZABLE = 0xbd2c04feebbff2d29fe1b04edf9a1d94ba7a836bad797bdd99c9e722e172cdd0;

    bytes32 constant TRUE = bytes32(uint256(1));
    bytes32 constant FALSE = bytes32(uint256(0));

    InitializableContract initializable;

    function setUp() public virtual {
        initializable = new InitializableContract();
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_Initialize() public {
        assertEq(vm.load(address(initializable), STORAGE__INITIALIZABLE), FALSE);

        initializable.initialize();

        assertEq(vm.load(address(initializable), STORAGE__INITIALIZABLE), TRUE);
    }

    function test_Cannot_InitializeTwice() public {
        assertEq(vm.load(address(initializable), STORAGE__INITIALIZABLE), FALSE);

        initializable.initialize();

        assertEq(vm.load(address(initializable), STORAGE__INITIALIZABLE), TRUE);

        vm.expectRevert(Errors.AlreadyInitialized.selector);
        initializable.initialize();
    }
}
