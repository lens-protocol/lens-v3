// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {OwnerAdminAccessControl} from "contracts/primitives/access-control/OwnerAdminAccessControl.sol";
import {IRoleBasedAccessControl} from "contracts/primitives/access-control/IRoleBasedAccessControl.sol";

contract OwnerAdminAccessControlTest is Test {
    OwnerAdminAccessControl public accessControl;
    address owner = makeAddr("OWNER");
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address eve = makeAddr("Eve");

    function setUp() public {
        accessControl = new OwnerAdminAccessControl(owner);
        vm.startPrank(owner);
        accessControl.setRole(alice, uint256(OwnerAdminAccessControl.Role.ADMIN), "");
        vm.stopPrank();
    }

    function testOwnerHasFullAccess() public {
        bool hasAccess = accessControl.hasAccess(owner, address(0), 0);
        assertTrue(hasAccess, "Owner should have full access");
    }

    function testAdminHasAccess() public {
        bool hasAccess = accessControl.hasAccess(alice, address(0), 0);
        assertTrue(hasAccess, "Admin should have access");
    }

    function testNonAdminNoAccess() public {
        bool hasAccess = accessControl.hasAccess(bob, address(0), 0);
        assertFalse(hasAccess, "Non-admin should not have access");
    }

    function testAddAdmin() public {
        vm.prank(owner);
        accessControl.setRole(bob, uint256(OwnerAdminAccessControl.Role.ADMIN), "");

        bool isAdmin = accessControl.hasRole(bob, uint256(OwnerAdminAccessControl.Role.ADMIN));
        assertTrue(isAdmin, "Bob should be assigned as Admin");
    }

    function testRemoveAdmin() public {
        vm.prank(owner);
        accessControl.setRole(alice, uint256(OwnerAdminAccessControl.Role.NONE), "");

        bool isAdmin = accessControl.hasRole(alice, uint256(OwnerAdminAccessControl.Role.ADMIN));
        assertFalse(isAdmin, "Alice should no longer be an Admin");
    }

    function testOnlyOwnerCanAssignRoles() public {
        vm.prank(bob);
        vm.expectRevert();
        accessControl.setRole(eve, uint256(OwnerAdminAccessControl.Role.ADMIN), "");
    }

    function testOwnershipTransferChangesRole() public {
        // Transfer ownership to Eve
        vm.prank(owner);
        accessControl.transferOwnership(eve);
        vm.prank(eve);
        accessControl.confirmOwnershipTransfer();
        vm.prank(owner);
        accessControl.confirmOwnershipTransfer();

        // Eve should now have OWNER privileges
        bool isOwner = accessControl.hasRole(eve, uint256(OwnerAdminAccessControl.Role.OWNER));
        assertTrue(isOwner, "Eve should be the new owner");

        // Old owner should lose OWNER role
        bool oldOwnerHasRole = accessControl.hasRole(owner, uint256(OwnerAdminAccessControl.Role.OWNER));
        assertFalse(oldOwnerHasRole, "Old owner should no longer have OWNER role");
    }

    function testRoleAssignmentForAlice() public {
        uint256 roleId = accessControl.getRole(alice);
        assertEq(roleId, uint256(OwnerAdminAccessControl.Role.ADMIN), "Role ID should match ADMIN for Alice");
    }

    function testRoleCheckForOwner() public {
        bool hasRole = accessControl.hasRole(owner, uint256(OwnerAdminAccessControl.Role.OWNER));
        assertTrue(hasRole, "Owner should have OWNER role");
    }

    function testRoleCheckForNonAdmin() public {
        bool hasRole = accessControl.hasRole(bob, uint256(OwnerAdminAccessControl.Role.ADMIN));
        assertFalse(hasRole, "Bob should not have ADMIN role");
    }

    function testRevokeAdminRole() public {
        vm.prank(owner);
        accessControl.setRole(alice, uint256(OwnerAdminAccessControl.Role.NONE), "");

        uint256 roleId = accessControl.getRole(alice);
        assertEq(roleId, uint256(OwnerAdminAccessControl.Role.NONE), "Alice's role should be NONE after revocation");
    }

    function testSetGlobalAccessShouldRevert() public {
        vm.prank(owner);
        vm.expectRevert();
        accessControl.setGlobalAccess(uint256(OwnerAdminAccessControl.Role.ADMIN), 0, IRoleBasedAccessControl.AccessPermission.GRANTED, "");
    }

    function testSetScopedAccessShouldRevert() public {
        vm.prank(owner);
        vm.expectRevert();
        accessControl.setScopedAccess(uint256(OwnerAdminAccessControl.Role.ADMIN), address(0), 0, IRoleBasedAccessControl.AccessPermission.GRANTED, "");
    }
}
