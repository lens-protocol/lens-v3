// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Lock} from "@core/upgradeability/Lock.sol";
import {Errors} from "@core/types/Errors.sol";

contract LockTest is Test {
    Lock lock;

    function setUp() public virtual {
        lock = new Lock({owner: address(this), locked: true});
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_ConstructorSetsProperOwnerAndLockStatus(address owner, bool locked) public {
        lock = new Lock({owner: owner, locked: locked});
        assertEq(lock.owner(), owner);
        assertEq(lock.isLocked(), locked);
    }

    function test_Cannot_SetLockStatus_IfNotOwner(address nonOwner, bool locked) public {
        vm.assume(nonOwner != lock.owner());

        vm.prank(nonOwner);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        lock.setLockStatus({locked: locked});
    }

    function test_SetLockStatus_IfOwner(bool locked) public {
        lock.setLockStatus({locked: locked});
        assertEq(lock.isLocked(), locked);

        lock.setLockStatus({locked: !locked});
        assertEq(lock.isLocked(), !locked);

        lock.setLockStatus({locked: locked});
        assertEq(lock.isLocked(), locked);
    }

    function test_Cannot_TransferOwnership_IfNotOwner(address nonOwner, address newOwner) public {
        vm.assume(nonOwner != lock.owner());

        vm.prank(nonOwner);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        lock.transferOwnership({newOwner: newOwner});
    }

    function test_TransferOwnership_IfOwner(address newOwner) public {
        lock.transferOwnership({newOwner: newOwner});
        assertEq(lock.owner(), newOwner);

        vm.prank(newOwner);
        lock.transferOwnership({newOwner: address(this)});
        assertEq(lock.owner(), address(this));
    }
}
