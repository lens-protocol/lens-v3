// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.17;

// import "forge-std/Test.sol";
// import {HierarchyRolesAccessControl} from "contracts/primitives/access-control/HierarchyRolesAccessControl.sol";
// import {IRoleBasedAccessControl} from "contracts/primitives/access-control/IRoleBasedAccessControl.sol";

// contract HierarchyRolesAccessControlTest is Test {
//     HierarchyRolesAccessControl public accessControl;
//     address owner = makeAddr("OWNER");
//     address alice = makeAddr("Alice");
//     address bob = makeAddr("Bob");
//     address eve = makeAddr("Eve");
//     uint256 constant RESOURCE_1_RID = uint256(keccak256("RESOURCE_1"));
//     uint256 constant RESOURCE_2_RID = uint256(keccak256("RESOURCE_2"));

//     function setUp() public {
//         accessControl = new HierarchyRolesAccessControl(owner);
//         vm.startPrank(owner);
//         // Assign roles to different accounts
//         accessControl.setGlobalAccess(uint256(HierarchyRolesAccessControl.Role.ADMIN), RESOURCE_1_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, "");
//         accessControl.setScopedAccess(uint256(HierarchyRolesAccessControl.Role.MODERATOR), address(this), RESOURCE_2_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, "");
//         vm.stopPrank();
//     }

//     function testOwnerHasFullAccess() public {
//         bool hasAccess = accessControl.hasAccess(owner, address(0), RESOURCE_1_RID);
//         assertTrue(hasAccess, "Owner should have full access to RESOURCE_1");
//     }

//     function testAdminGlobalAccessGranted() public {
//         bool hasAccess = accessControl.hasAccess(alice, address(0), RESOURCE_1_RID);
//         assertTrue(hasAccess, "Alice should have ADMIN global access to RESOURCE_1");
//     }

//     function testModeratorScopedAccessGranted() public {
//         bool hasAccess = accessControl.hasAccess(bob, address(this), RESOURCE_2_RID);
//         assertTrue(hasAccess, "Bob should have MODERATOR scoped access to RESOURCE_2");
//     }

//     function testAdminCannotAccessAnotherResource() public {
//         bool hasAccess = accessControl.hasAccess(alice, address(this), RESOURCE_2_RID);
//         assertFalse(hasAccess, "Alice (ADMIN) should not have access to RESOURCE_2 at this location");
//     }

//     function testModeratorCannotAccessUnassignedResource() public {
//         bool hasAccess = accessControl.hasAccess(bob, address(0), RESOURCE_1_RID);
//         assertFalse(hasAccess, "Bob (MODERATOR) should not have access to RESOURCE_1 globally");
//     }

//     function testOwnershipTransferChangesRole() public {
//         // Transfer ownership to Eve
//         vm.prank(owner);
//         accessControl.transferOwnership(eve);
//         vm.prank(eve);
//         accessControl.confirmOwnershipTransfer();

//         // Eve should now have OWNER privileges
//         bool hasAccess = accessControl.hasAccess(eve, address(0), RESOURCE_1_RID);
//         assertTrue(hasAccess, "New owner (Eve) should have full access to RESOURCE_1");

//         // Old owner should lose access
//         hasAccess = accessControl.hasAccess(owner, address(0), RESOURCE_1_RID);
//         assertFalse(hasAccess, "Old owner should no longer have access after ownership transfer");
//     }

//     function testRoleAssignmentForAlice() public {
//         uint256 roleId = accessControl.getRole(alice);
//         assertEq(roleId, uint256(HierarchyRolesAccessControl.Role.ADMIN), "Role ID should match ADMIN for Alice");
//     }

//     function testRoleCheckForModerator() public {
//         bool hasRole = accessControl.hasRole(bob, uint256(HierarchyRolesAccessControl.Role.MODERATOR));
//         assertTrue(hasRole, "Bob should have MODERATOR role");
//     }

//     function testInvalidRoleId() public {
//         uint256 invalidId = uint256(type(uint160).max) + 1;
//         vm.prank(owner);
//         vm.expectRevert("Invalid roleId");
//         accessControl.setGlobalAccess(invalidId, RESOURCE_1_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, "");
//     }

//     function testSetGlobalAccessByNonOwnerFails() public {
//         vm.prank(bob); // Non-owner tries to set global access
//         vm.expectRevert("Ownable: caller is not the owner");
//         accessControl.setGlobalAccess(uint256(HierarchyRolesAccessControl.Role.ADMIN), RESOURCE_1_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, "");
//     }
// }
