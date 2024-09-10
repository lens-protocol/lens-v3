// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Graph, Follow, IGraphRule, IFollowRule} from "../../contracts/primitives/graph/Graph.sol";
import {OwnerOnlyAccessControl} from "../../contracts/primitives/access-control/OwnerOnlyAccessControl.sol";
import {
    AddressBasedAccessControl,
    IRoleBasedAccessControl
} from "../../contracts/primitives/access-control/AddressBasedAccessControl.sol";
import {MockGraphRule} from "../mock/MockGraphRule.sol";
import {MockFollowRule} from "../mock/MockFollowRule.sol";

contract GraphTest is Test {
    Graph public graph;
    AddressBasedAccessControl public addressBasedAccessControl;
    OwnerOnlyAccessControl public ownerOnlyAccessControl;
    address public owner = address(1);
    address public adminSetRules = address(2);
    address public adminSetMetadata = address(3);
    address public addminChangeAccessControl = address(4);
    address public user1 = address(5);
    address public user2 = address(6);
    address public user3 = address(7);

    uint256 constant SET_RULES_RID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_RID = uint256(keccak256("SET_METADATA"));
    uint256 constant CHANGE_ACCESS_CONTROL_RID = uint256(keccak256("CHANGE_ACCESS_CONTROL"));

    function setUp() public {
        vm.startPrank(owner);
        addressBasedAccessControl = new AddressBasedAccessControl(owner);
        ownerOnlyAccessControl = new OwnerOnlyAccessControl(owner);
        // Set up roles
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(adminSetRules)), SET_RULES_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, ""
        );
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(adminSetMetadata)), SET_METADATA_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, ""
        );
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(addminChangeAccessControl)),
            CHANGE_ACCESS_CONTROL_RID,
            IRoleBasedAccessControl.AccessPermission.GRANTED,
            ""
        );
        graph = new Graph("test-graph", addressBasedAccessControl);
        vm.stopPrank();
    }

    function testSetGraphRulesWithCorrectRole() public {
        IGraphRule mockRules = IGraphRule(address(5));

        vm.prank(adminSetRules);
        graph.setGraphRules(mockRules);

        assertEq(address(graph.getGraphRules()), address(mockRules));
    }

    function testCannotSetGraphRulesWithoutCorrectRole() public {
        IGraphRule mockRules = IGraphRule(address(5));

        vm.prank(user1);
        vm.expectRevert();
        graph.setGraphRules(mockRules);
    }

    function testSetAccessControlWithCorrectRole() public {
        vm.prank(addminChangeAccessControl);
        graph.setAccessControl(ownerOnlyAccessControl);
    }

    function testCannotSetAccessControlWithoutCorrectRole() public {
        vm.prank(user1);
        vm.expectRevert();
        graph.setAccessControl(ownerOnlyAccessControl);
    }

    function testSetFollowRules() public {
        IFollowRule mockFollowRules = IFollowRule(address(5));

        vm.prank(user1);
        graph.setFollowRules(user1, mockFollowRules, "");

        assertEq(address(graph.getFollowRules(user1)), address(mockFollowRules));
    }

    function testSetFollowRulesWithGraphRules() public {
        // Set up mock graph rules
        MockGraphRule mockGraphRule = new MockGraphRule();
        vm.prank(owner);
        graph.setGraphRules(mockGraphRule);

        IFollowRule mockFollowRules = IFollowRule(address(6));
        bytes memory testData = "test data";

        vm.prank(user1);
        graph.setFollowRules(user1, mockFollowRules, testData);

        // Check that the follow rules were set
        assertEq(address(graph.getFollowRules(user1)), address(mockFollowRules));

        // Check that processFollowRulesChange was called on the mock graph rules
        assertTrue(mockGraphRule.processFollowRulesChangeCalled());
        assertEq(mockGraphRule.lastAccount(), user1);
        assertEq(address(mockGraphRule.lastFollowRules()), address(mockFollowRules));
        assertEq(mockGraphRule.lastData(), testData);
    }

    function testCannotSetFollowRulesForOtherAccount() public {
        IFollowRule mockFollowRules = IFollowRule(address(6));
        bytes memory testData = "test data";

        vm.prank(user2);
        vm.expectRevert();
        graph.setFollowRules(user1, mockFollowRules, testData);
    }

    function testFollow() public {
        vm.prank(user1);
        uint256 followId = graph.follow(user1, user2, 0, "", "");

        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
        assertEq(graph.getFollowerById(user2, followId), user1);

        Follow memory follow = graph.getFollow(user1, user2);
        assertEq(follow.id, followId);
        assertEq(follow.timestamp, block.timestamp);
    }

    function testFollowWithSpecificId() public {
        uint256 specificId = 5;
        vm.startPrank(user1);
        uint256 followId;

        // Increment followId by 1 each time
        for (uint256 i = 0; i < specificId + 1; i++) {
            followId = graph.follow(user1, user2, 0, "", "");
            graph.unfollow(user1, user2, "");
        }

        followId = graph.follow(user1, user2, specificId, "", "");

        assertEq(followId, specificId);
        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
        assertEq(graph.getFollowerById(user2, followId), user1);
    }

    function testFollowWithGraphRules() public {
        MockGraphRule mockGraphRule = new MockGraphRule();
        vm.prank(owner);
        graph.setGraphRules(mockGraphRule);

        bytes memory graphRulesData = "graph rules data";
        vm.prank(user1);
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, "");

        assertTrue(mockGraphRule.processFollowCalled());
        assertEq(mockGraphRule.lastFollowerAccount(), user1);
        assertEq(mockGraphRule.lastTargetAccount(), user2);
        assertEq(mockGraphRule.lastFollowId(), followId);
        assertEq(mockGraphRule.lastGraphRulesData(), graphRulesData);
    }

    function testFollowWithFollowRules() public {
        MockFollowRule mockFollowRule = new MockFollowRule();

        vm.prank(user2);
        graph.setFollowRules(user2, mockFollowRule, "");

        bytes memory followRulesData = "follow rules data";
        vm.prank(user1);
        uint256 followId = graph.follow(user1, user2, 0, "", followRulesData);

        assertTrue(mockFollowRule.processFollowCalled());
        assertEq(mockFollowRule.lastFollowerAccount(), user1);
        assertEq(mockFollowRule.lastFollowId(), followId);
        assertEq(mockFollowRule.lastFollowRulesData(), followRulesData);
    }

    function testCannotFollowUsingOtherAccount() public {
        vm.prank(user1);
        vm.expectRevert();
        graph.follow(user2, user1, 0, "", "");
    }

    function testCannotFollowTwice() public {
        vm.startPrank(user1);
        graph.follow(user1, user2, 0, "", "");

        vm.expectRevert();
        graph.follow(user1, user2, 0, "", "");
        vm.stopPrank();

        assertEq(graph.getFollowersCount(user2), 1);
    }

    function testCannotFollowSelf() public {
        vm.prank(user1);
        vm.expectRevert();
        graph.follow(user1, user1, 0, "", "");
        assertEq(graph.getFollowersCount(user1), 0);
    }

    function testCannotFollowWithIdMoreThanLastIdAssigned() public {
        uint256 specificId = 42;
        vm.prank(user1);

        // Follow ID more than lastFollowIdAssigned
        vm.expectRevert();
        uint256 followId = graph.follow(user1, user2, specificId, "", "");
    }

    function testCannotFollowWithTakenId() public {
        vm.prank(user1);
        // Increase the current followId of user3 to 1
        uint256 followId = graph.follow(user1, user3, 0, "", "");
        assertEq(followId, 1);

        // Transaction reverted because followId is already taken
        vm.prank(user2);
        vm.expectRevert();
        graph.follow(user2, user3, 1, "", "");
    }

    function testUnfollow() public {
        vm.startPrank(user1);
        graph.follow(user1, user2, 0, "", "");
        uint256 followId = graph.unfollow(user1, user2, "");
        vm.stopPrank();

        assertFalse(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 0);
        assertEq(graph.getFollowerById(user2, followId), address(0));
    }

    function testUnfollowWithGraphRules() public {
        MockGraphRule mockGraphRule = new MockGraphRule();
        vm.prank(owner);
        graph.setGraphRules(mockGraphRule);

        vm.prank(user1);
        uint256 followId = graph.follow(user1, user2, 0, "", "");

        bytes memory graphRulesData = "unfollow graph rules data";
        vm.prank(user1);
        uint256 unfollowId = graph.unfollow(user1, user2, graphRulesData);

        assertTrue(mockGraphRule.processUnfollowCalled());
        assertEq(mockGraphRule.lastUnfollowerAccount(), user1);
        assertEq(mockGraphRule.lastUnfollowedAccount(), user2);
        assertEq(mockGraphRule.lastUnfollowId(), unfollowId);
        assertEq(mockGraphRule.lastUnfollowGraphRulesData(), graphRulesData);
        assertEq(followId, unfollowId);
    }

    function testCannotUnfollowWithoutFollowing() public {
        vm.prank(user1);
        vm.expectRevert();
        graph.unfollow(user1, user2, "");
    }

    function testCannotUnfollowUsingOtherAccount() public {
        vm.prank(user1);
        graph.follow(user1, user2, 0, "", "");

        vm.prank(user3);
        vm.expectRevert();
        graph.unfollow(user1, user2, "");
    }
}
