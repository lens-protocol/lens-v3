// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {PermissionlessAccessControl} from "contracts/primitives/access-control/PermissionlessAccessControl.sol";
import {IAccessControl} from "contracts/primitives/access-control/IAccessControl.sol";

contract PermissionlessAccessControlTest is Test {
    PermissionlessAccessControl public accessControl;
    address owner = makeAddr("OWNER");
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address eve = makeAddr("Eve");

    function setUp() public {
        accessControl = new PermissionlessAccessControl();
    }

    function testEveryoneHasAccess() public {
        bool ownerAccess = accessControl.hasAccess(owner, address(0), 0);
        bool aliceAccess = accessControl.hasAccess(alice, address(0), 0);
        bool bobAccess = accessControl.hasAccess(bob, address(0), 0);
        bool eveAccess = accessControl.hasAccess(eve, address(0), 0);

        assertTrue(ownerAccess, "Owner should have access");
        assertTrue(aliceAccess, "Alice should have access");
        assertTrue(bobAccess, "Bob should have access");
        assertTrue(eveAccess, "Eve should have access");
    }

    function testEveryoneHasAccessToAnyResource() public {
        address resource1 = makeAddr("Resource1");
        address resource2 = makeAddr("Resource2");
        address resource3 = makeAddr("Resource3");

        bool ownerAccessResource1 = accessControl.hasAccess(owner, resource1, 1);
        bool aliceAccessResource2 = accessControl.hasAccess(alice, resource2, 2);
        bool bobAccessResource3 = accessControl.hasAccess(bob, resource3, 3);

        assertTrue(ownerAccessResource1, "Owner should have access to Resource1");
        assertTrue(aliceAccessResource2, "Alice should have access to Resource2");
        assertTrue(bobAccessResource3, "Bob should have access to Resource3");
    }

    function testAccessDoesNotDependOnResourceId() public {
        bool accessWithResource1 = accessControl.hasAccess(alice, address(0), 1);
        bool accessWithResource2 = accessControl.hasAccess(alice, address(0), 100);
        bool accessWithResource3 = accessControl.hasAccess(alice, address(0), 999);

        assertTrue(accessWithResource1, "Alice should have access to resource ID 1");
        assertTrue(accessWithResource2, "Alice should have access to resource ID 100");
        assertTrue(accessWithResource3, "Alice should have access to resource ID 999");
    }
}
