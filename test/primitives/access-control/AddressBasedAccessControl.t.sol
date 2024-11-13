// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {AddressBasedAccessControl} from "contracts/primitives/access-control/AddressBasedAccessControl.sol";
import {IRoleBasedAccessControl} from "contracts/primitives/access-control/IRoleBasedAccessControl.sol";

contract AddressBasedAccessControlTest is Test {
    AddressBasedAccessControl public addressBasedAccessControl;
    address owner = makeAddr("OWNER");
    address resourceLocation = makeAddr("ResourceLocation");
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address eve = makeAddr("Eve");
    address mallory = makeAddr("Mallory");
    uint256 constant FUNCTION_1_RID = uint256(keccak256("FUNCTION_1"));
    uint256 constant FUNCTION_2_RID = uint256(keccak256("FUNCTION_2"));
    uint256 constant FUNCTION_3_RID = uint256(keccak256("FUNCTION_3"));
    uint256 constant FUNCTION_4_RID = uint256(keccak256("FUNCTION_4"));
    function setUp() public {
        addressBasedAccessControl = new AddressBasedAccessControl(owner);
        vm.startPrank(owner);
        addressBasedAccessControl.setGlobalAccess(_addressToRoleId(alice), FUNCTION_1_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, "");
        addressBasedAccessControl.setGlobalAccess(_addressToRoleId(bob), FUNCTION_2_RID, IRoleBasedAccessControl.AccessPermission.DENIED, "");
        addressBasedAccessControl.setScopedAccess(_addressToRoleId(eve), resourceLocation, FUNCTION_3_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, "");
        addressBasedAccessControl.setScopedAccess(_addressToRoleId(mallory), resourceLocation, FUNCTION_4_RID, IRoleBasedAccessControl.AccessPermission.DENIED, "");
        vm.stopPrank();
    }

    function testGlobalAccessGranted() public {
        bool hasAccess = addressBasedAccessControl.hasAccess(alice, address(0), FUNCTION_1_RID);
        assertTrue(hasAccess, "Alice should have global access to FUNCTION_1_RID");
    }

    function testGlobalAccessDenied() public {
        bool hasAccess = addressBasedAccessControl.hasAccess(bob, address(0), FUNCTION_2_RID);
        assertFalse(hasAccess, "Bob should be denied global access to FUNCTION_2_RID");
    }

    function testScopedAccessGranted() public {
        bool hasAccess = addressBasedAccessControl.hasAccess(eve, resourceLocation, FUNCTION_3_RID);
        assertTrue(hasAccess, "Eve should have scoped access to FUNCTION_3_RID at resourceLocation");
    }

    function testScopedAccessDenied() public {
        bool hasAccess = addressBasedAccessControl.hasAccess(mallory, resourceLocation, FUNCTION_4_RID);
        assertFalse(hasAccess, "Mallory should be denied scoped access to FUNCTION_4_RID at resourceLocation");
    }

    function testOwnerAlwaysHasAccess() public {
        bool hasAccessGlobal = addressBasedAccessControl.hasAccess(owner, address(0), FUNCTION_1_RID);
        bool hasAccessScoped = addressBasedAccessControl.hasAccess(owner, resourceLocation, FUNCTION_4_RID);
        
        assertTrue(hasAccessGlobal, "Owner should have global access to FUNCTION_1_RID");
        assertTrue(hasAccessScoped, "Owner should have scoped access to FUNCTION_4_RID at resourceLocation");
    }


    function testRoleAssignmentForAlice() public {
        uint256 roleId = addressBasedAccessControl.getRole(alice);
        assertEq(roleId, _addressToRoleId(alice), "Role ID should match Alice's address");
    }



    function testRoleCheckForAlice() public {
        bool hasRole = addressBasedAccessControl.hasRole(alice, _addressToRoleId(alice));
        assertTrue(hasRole, "Alice should have the correct role ID");
    }



    function testInvalidRoleId() public {
        uint256 invalidId = uint256(type(uint160).max) + 1;
        vm.prank(owner);
        vm.expectRevert("Invalid roleId");
        addressBasedAccessControl.setGlobalAccess(invalidId, FUNCTION_1_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, "");
    }

    function testOwnershipTransfer() public {
        // Transfer ownership to Alice
        vm.prank(owner);
        addressBasedAccessControl.transferOwnership(alice);
        vm.prank(alice);
        addressBasedAccessControl.confirmOwnershipTransfer();
        vm.prank(owner);
        addressBasedAccessControl.confirmOwnershipTransfer();
        
        // Owner (Alice) should now have full access
        bool hasAccess = addressBasedAccessControl.hasAccess(alice, address(0), FUNCTION_2_RID);
        assertTrue(hasAccess, "New owner (Alice) should have access to FUNCTION_2_RID after ownership transfer");
    }


    // Helpers
    function _addressToRoleId(address account) internal pure returns (uint256) {
        return uint256(uint160(account));
    }

}
