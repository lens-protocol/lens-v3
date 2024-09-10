// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Username, IUsernameRule} from "../../contracts/primitives/username/Username.sol";
import {
    AddressBasedAccessControl,
    IRoleBasedAccessControl
} from "../../contracts/primitives/access-control/AddressBasedAccessControl.sol";
import {MockUsernameRule} from "../mock/MockUsernameRule.sol";

contract UsernameTest is Test {
    Username private username;
    AddressBasedAccessControl public addressBasedAccessControl;
    MockUsernameRule public mockUsernameRule;

    address public owner = address(1);
    address public adminSetRules = address(2);
    address public adminChangeAccessControl = address(3);
    address public user1 = address(4);
    address public user2 = address(5);

    uint256 constant SET_RULES_RID = uint256(keccak256("SET_RULES"));
    uint256 constant CHANGE_ACCESS_CONTROL_RID = uint256(keccak256("CHANGE_ACCESS_CONTROL"));

    function setUp() public {
        vm.startPrank(owner);
        addressBasedAccessControl = new AddressBasedAccessControl(owner);
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(adminSetRules)), SET_RULES_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, ""
        );
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(adminChangeAccessControl)),
            CHANGE_ACCESS_CONTROL_RID,
            IRoleBasedAccessControl.AccessPermission.GRANTED,
            ""
        );
        username = new Username("test", addressBasedAccessControl);
        mockUsernameRule = new MockUsernameRule();
        vm.stopPrank();

        vm.prank(adminSetRules);
        username.setUsernameRules(IUsernameRule(address(mockUsernameRule)));
    }

    function testInitialState() public {
        assertEq(username.getNamespace(), "test");
        assertEq(username.getAccessControl(), address(addressBasedAccessControl));
        assertEq(username.getUsernameRules(), address(mockUsernameRule));
    }

    function testSetUsernameRules() public {
        MockUsernameRule newRule = new MockUsernameRule();

        vm.prank(adminSetRules);
        username.setUsernameRules(IUsernameRule(address(newRule)));

        assertEq(username.getUsernameRules(), address(newRule));
    }

    function testCannotSetUsernameRulesWithoutPermission() public {
        MockUsernameRule newRule = new MockUsernameRule();

        vm.prank(user1);
        vm.expectRevert();
        username.setUsernameRules(IUsernameRule(address(newRule)));
    }

    function testSetAccessControl() public {
        AddressBasedAccessControl newAccessControl = new AddressBasedAccessControl(owner);

        vm.prank(adminChangeAccessControl);
        username.setAccessControl(newAccessControl);

        assertEq(username.getAccessControl(), address(newAccessControl));
    }

    function testCannotSetAccessControlWithoutPermission() public {
        AddressBasedAccessControl newAccessControl = new AddressBasedAccessControl(owner);

        vm.prank(user1);
        vm.expectRevert();
        username.setAccessControl(newAccessControl);
    }

    function testRegisterUsername() public {
        vm.prank(user1);
        username.registerUsername(user1, "alice", "");

        assertEq(username.usernameOf(user1), "alice");
        assertEq(username.accountOf("alice"), user1);
    }

    function testCannotRegisterDuplicateUsername() public {
        vm.prank(user1);
        username.registerUsername(user1, "alice", "");

        vm.prank(user2);
        vm.expectRevert();
        username.registerUsername(user2, "alice", "");
    }

    function testCannotRegisterMultipleUsernames() public {
        vm.startPrank(user1);
        username.registerUsername(user1, "alice", "");

        vm.expectRevert();
        username.registerUsername(user1, "bob", "");
        vm.stopPrank();
    }

    function testUnregisterUsername() public {
        vm.prank(user1);
        username.registerUsername(user1, "alice", "");

        vm.prank(user1);
        username.unregisterUsername("alice", "");

        assertEq(username.usernameOf(user1), "");
        assertEq(username.accountOf("alice"), address(0));
    }

    function testCannotUnregisterOthersUsername() public {
        vm.prank(user1);
        username.registerUsername(user1, "alice", "");

        vm.prank(user2);
        vm.expectRevert();
        username.unregisterUsername("alice", "");
    }
}
