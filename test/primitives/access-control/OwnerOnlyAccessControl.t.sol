// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {OwnerOnlyAccessControl} from "contracts/primitives/access-control/OwnerOnlyAccessControl.sol";
import {IAccessControl} from "contracts/primitives/access-control/IAccessControl.sol";

contract OwnerOnlyAccessControlTest is Test {
    OwnerOnlyAccessControl public accessControl;
    address owner = makeAddr("OWNER");
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address eve = makeAddr("Eve");

    function setUp() public {
        accessControl = new OwnerOnlyAccessControl(owner);
    }

    function testOwnerHasFullAccess() public {
        bool hasAccess = accessControl.hasAccess(owner, address(0), 0);
        assertTrue(hasAccess, "Owner should have full access");
    }

    function testNonOwnerNoAccess() public {
        bool hasAccessAlice = accessControl.hasAccess(alice, address(0), 0);
        assertFalse(hasAccessAlice, "Alice (non-owner) should not have access");

        bool hasAccessBob = accessControl.hasAccess(bob, address(0), 0);
        assertFalse(hasAccessBob, "Bob (non-owner) should not have access");
    }

    function testOwnershipTransfer() public {
        // Transfer ownership to Eve
        vm.prank(owner);
        accessControl.transferOwnership(eve);
        vm.prank(eve);
        accessControl.confirmOwnershipTransfer();
        vm.prank(owner);
        accessControl.confirmOwnershipTransfer();

        // Eve should now have full access
        bool hasAccess = accessControl.hasAccess(eve, address(0), 0);
        assertTrue(hasAccess, "Eve should have full access after ownership transfer");

        // Old owner (previous owner) should no longer have access
        bool oldOwnerHasAccess = accessControl.hasAccess(owner, address(0), 0);
        assertFalse(oldOwnerHasAccess, "Old owner should no longer have access after ownership transfer");
    }

    function testNonOwnerCannotTransferOwnership() public {
        // Try to transfer ownership as a non-owner (bob)
        vm.prank(bob);
        vm.expectRevert();
        accessControl.transferOwnership(alice);
    }

    function testOwnerCanTransferOwnership() public {
        // Owner should be able to transfer ownership
        vm.prank(owner);
        accessControl.transferOwnership(alice);
        vm.prank(alice);
        accessControl.confirmOwnershipTransfer();
        vm.prank(owner);
        accessControl.confirmOwnershipTransfer();

        bool isNewOwner = accessControl.hasAccess(alice, address(0), 0);
        assertTrue(isNewOwner, "Alice should have access after becoming the new owner");
    }
}
