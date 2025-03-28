// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.

pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {Errors} from "@core/types/Errors.sol";
import {Follow} from "@core/interfaces/IGraph.sol";
import {Graph} from "@core/primitives/graph/Graph.sol";
import {IGraph} from "@core/interfaces/IGraph.sol";
import {IGraphRule} from "@core/interfaces/IGraphRule.sol";
import {IMetadataBased} from "@core/interfaces/IMetadataBased.sol";
import {KeyValue} from "@core/types/Types.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {Rule, RuleConfigurationChange} from "@core/types/Types.sol";
import {RuleExecutionTest} from "test/primitives/rules/RuleExecution.t.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";

contract GraphTest is RulesTest, BaseDeployments, RuleExecutionTest {
    IGraph graph;

    address sourceAccount = makeAddr("SOURCE");
    address targetAccount = makeAddr("TARGET");
    address graphOwner = makeAddr("GRAPH_OWNER");

    MockAccessControl mockAccessControl;
    address graphForRules;

    function setUp() public override(RulesTest, BaseDeployments, RuleExecutionTest) {
        BaseDeployments.setUp();

        graph = IGraph(
            lensFactory.deployGraph({
                metadataURI: "some metadata uri",
                owner: graphOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        mockAccessControl = new MockAccessControl();

        vm.prank(address(lensFactory));
        graphForRules = graphFactory.deployGraph({
            metadataURI: "uri://graph",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        RulesTest.setUp();
        RuleExecutionTest.setUp();
    }

    function test_Follow(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // Store initial state
        uint256 initialFollowersCount = graph.getFollowersCount(target);
        uint256 initialFollowingCount = graph.getFollowingCount(follower);
        assertFalse(graph.isFollowing(follower, target), "Should not have been following before");

        // Perform follow operation
        vm.prank(follower);
        uint256 followId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify state changes
        assertEq(graph.getFollowersCount(target), initialFollowersCount + 1, "Followers count should increase by 1");
        assertEq(graph.getFollowingCount(follower), initialFollowingCount + 1, "Following count should increase by 1");
        assertTrue(graph.isFollowing(follower, target), "Should be following after follow operation");

        // Verify follow data
        Follow memory followData = graph.getFollow(follower, target);
        assertEq(followData.id, followId, "Follow ID should match returned ID");
        assertEq(followData.timestamp, block.timestamp, "Follow timestamp should be current block");

        // Verify follower by ID
        assertEq(graph.getFollowerById(target, followId), follower, "Should be able to get follower by ID");
    }

    function test_Unfollow(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // First follow to set up the test
        vm.prank(follower);
        uint256 followId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
        assertTrue(graph.isFollowing(follower, target), "Should be following before unfollow");

        // Store state after follow
        uint256 followersCount = graph.getFollowersCount(target);
        uint256 followingCount = graph.getFollowingCount(follower);

        // Perform unfollow operation
        vm.prank(follower);
        uint256 unfollowedId = graph.unfollow({
            followerAccount: follower,
            accountToUnfollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify state changes
        assertEq(graph.getFollowersCount(target), followersCount - 1, "Followers count should decrease by 1");
        assertEq(graph.getFollowingCount(follower), followingCount - 1, "Following count should decrease by 1");
        assertFalse(graph.isFollowing(follower, target), "Should not be following after unfollow");
        assertEq(unfollowedId, followId, "Unfollow should return the same ID as follow");

        // Verify follow data is removed
        vm.expectRevert(Errors.DoesNotExist.selector);
        graph.getFollow(follower, target);

        // Verify follower by ID is removed
        vm.expectRevert(Errors.DoesNotExist.selector);
        graph.getFollowerById(target, followId);
    }

    function test_Follow_WithCustomParams(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // Create custom parameters
        KeyValue[] memory customParams = new KeyValue[](2);
        customParams[0] = KeyValue({key: "reason", value: "I like their content"});
        customParams[1] = KeyValue({key: "tags", value: "tech,blockchain,web3"});

        // Store initial state
        uint256 initialFollowersCount = graph.getFollowersCount(target);
        uint256 initialFollowingCount = graph.getFollowingCount(follower);

        uint256 expectedFollowId = 1;

        // Expect customParams to be emitted in the following event
        vm.expectEmit(true, true, true, true);
        emit IGraph.Lens_Graph_Followed({
            followerAccount: follower,
            accountToFollow: target,
            followId: expectedFollowId,
            customParams: customParams,
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            source: address(0),
            extraData: _emptyKeyValueArray()
        });

        // Perform follow operation with custom parameters
        vm.prank(follower);
        uint256 followId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: customParams,
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        assertEq(followId, expectedFollowId, "Follow ID should match expected ID");

        // Verify state changes
        assertEq(graph.getFollowersCount(target), initialFollowersCount + 1, "Followers count should increase by 1");
        assertEq(graph.getFollowingCount(follower), initialFollowingCount + 1, "Following count should increase by 1");
        assertTrue(graph.isFollowing(follower, target), "Should be following after follow operation");

        // Verify follow data
        Follow memory followData = graph.getFollow(follower, target);
        assertEq(followData.id, followId, "Follow ID should match returned ID");
        assertEq(followData.timestamp, block.timestamp, "Follow timestamp should be current block");

        // Verify follower by ID
        assertEq(graph.getFollowerById(target, followId), follower, "Should be able to get follower by ID");
    }

    function test_Unfollow_WithCustomParams(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // First follow to set up the test
        vm.prank(follower);
        uint256 followId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Store state after follow
        uint256 followersCount = graph.getFollowersCount(target);
        uint256 followingCount = graph.getFollowingCount(follower);
        assertTrue(graph.isFollowing(follower, target), "Should be following before unfollow");

        // Create custom parameters for unfollow
        KeyValue[] memory customParams = new KeyValue[](2);
        customParams[0] = KeyValue({key: "reason", value: "Content no longer interests me"});
        customParams[1] = KeyValue({key: "feedback", value: "Good content but different interests now"});

        // Expect customParams to be emitted in the unfollowing event
        vm.expectEmit(true, true, true, true);
        emit IGraph.Lens_Graph_Unfollowed({
            followerAccount: follower,
            accountToUnfollow: target,
            followId: followId,
            customParams: customParams,
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            source: address(0)
        });

        // Perform unfollow operation with custom parameters
        vm.prank(follower);
        uint256 unfollowedId = graph.unfollow({
            followerAccount: follower,
            accountToUnfollow: target,
            customParams: customParams,
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify state changes
        assertEq(graph.getFollowersCount(target), followersCount - 1, "Followers count should decrease by 1");
        assertEq(graph.getFollowingCount(follower), followingCount - 1, "Following count should decrease by 1");
        assertFalse(graph.isFollowing(follower, target), "Should not be following after unfollow");
        assertEq(unfollowedId, followId, "Unfollow should return the same ID as follow");

        // Verify follow data is removed
        vm.expectRevert(Errors.DoesNotExist.selector);
        graph.getFollow(follower, target);

        // Verify follower by ID is removed
        vm.expectRevert(Errors.DoesNotExist.selector);
        graph.getFollowerById(target, followId);
    }

    function test_CannotFollow_DifferentSender(address sender, address follower, address target) public {
        vm.assume(sender != address(0));
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(sender != follower);
        vm.assume(follower != target);
        vm.assume(sender != target);

        // Try to follow on behalf of a different account
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function test_CannotFollow_ZeroAddress(address follower) public {
        vm.assume(follower != address(0));

        vm.prank(follower);
        vm.expectRevert(Errors.InvalidParameter.selector);
        graph.follow({
            followerAccount: follower,
            accountToFollow: address(0),
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function test_CannotUnfollow_ZeroAddress(address follower) public {
        vm.assume(follower != address(0));

        vm.prank(follower);
        vm.expectRevert(Errors.InvalidParameter.selector);
        graph.unfollow({
            followerAccount: follower,
            accountToUnfollow: address(0),
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotFollow_Self(address account) public {
        vm.assume(account != address(0));

        vm.prank(account);
        vm.expectRevert(Errors.ActionOnSelf.selector);
        graph.follow({
            followerAccount: account,
            accountToFollow: account,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function test_CannotFollow_AlreadyFollowing(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // First follow
        vm.prank(follower);
        graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Try to follow again
        vm.prank(follower);
        vm.expectRevert(Errors.CannotFollowAgain.selector);
        graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function test_CannotUnfollow_NotFollowing(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // Try to unfollow without following first
        vm.prank(follower);
        vm.expectRevert(Errors.NotFollowing.selector);
        graph.unfollow({
            followerAccount: follower,
            accountToUnfollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotUnfollow_DifferentSender(address sender, address follower, address target) public {
        vm.assume(sender != address(0));
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(sender != follower);
        vm.assume(follower != target);
        vm.assume(sender != target);

        // First, have the follower follow the target
        vm.prank(follower);
        graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Try to unfollow on behalf of a different account
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        graph.unfollow({
            followerAccount: follower,
            accountToUnfollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_FollowId_Increments() public {
        address target = makeAddr("TARGET");
        address[] memory followers = new address[](3);
        for (uint256 i = 0; i < 3; i++) {
            followers[i] = makeAddr(string.concat("FOLLOWER_", vm.toString(i)));
        }

        uint256[] memory followIds = new uint256[](3);

        // Have multiple followers follow the same target
        for (uint256 i = 0; i < followers.length; i++) {
            vm.prank(followers[i]);
            followIds[i] = graph.follow({
                followerAccount: followers[i],
                accountToFollow: target,
                customParams: _emptyKeyValueArray(),
                graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
                followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
                extraData: _emptyKeyValueArray()
            });

            // Verify each follow ID is incremented by 1
            if (i > 0) {
                assertEq(followIds[i], followIds[i - 1] + 1, "Follow ID should increment by 1");
            }

            // Verify follow data has correct ID
            Follow memory followData = graph.getFollow(followers[i], target);
            assertEq(followData.id, followIds[i], "Follow data ID should match returned ID");

            // Verify follower by ID
            assertEq(graph.getFollowerById(target, followIds[i]), followers[i], "Should be able to get follower by ID");
        }
    }

    function test_GetFollowerById(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // First follow to get a follow ID
        vm.prank(follower);
        uint256 followId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify we can get the follower by ID
        assertEq(graph.getFollowerById(target, followId), follower, "Should be able to get follower by ID");

        // Verify the follow data matches
        Follow memory followData = graph.getFollow(follower, target);
        assertEq(followData.id, followId, "Follow data ID should match");
        assertEq(followData.timestamp, block.timestamp, "Follow timestamp should be current block");
    }

    function test_GetFollowerById_NonexistentId(address target, uint256 followId) public {
        vm.assume(target != address(0));
        vm.assume(followId != 0); // Follow ID 0 is invalid by design

        // Try to get a follower by a non-existent ID
        vm.expectRevert(Errors.DoesNotExist.selector);
        graph.getFollowerById(target, followId);
    }

    function test_GetFollow(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // First follow to create the relationship
        vm.prank(follower);
        uint256 followId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Get and verify follow data
        Follow memory followData = graph.getFollow(follower, target);
        assertEq(followData.id, followId, "Follow ID should match");
        assertEq(followData.timestamp, block.timestamp, "Follow timestamp should be current block");

        // Verify the relationship exists
        assertTrue(graph.isFollowing(follower, target), "Should be following");
        assertEq(graph.getFollowerById(target, followId), follower, "Should be able to get follower by ID");
    }

    function test_GetFollow_NonexistentFollow(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // Try to get follow data for a non-existent follow relationship
        vm.expectRevert(Errors.DoesNotExist.selector);
        graph.getFollow(follower, target);

        // Verify the relationship doesn't exist
        assertFalse(graph.isFollowing(follower, target), "Should not be following");
    }

    function test_IsFollowing(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // Initially should not be following
        assertFalse(graph.isFollowing(follower, target), "Should not be following initially");

        // Follow to create the relationship
        vm.prank(follower);
        graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify isFollowing returns true and follow data is valid
        assertTrue(graph.isFollowing(follower, target), "Should be following after follow operation");
        Follow memory followData = graph.getFollow(follower, target);
        assertGt(followData.id, 0, "Follow ID should be greater than 0");
        assertEq(followData.timestamp, block.timestamp, "Follow timestamp should be current block");

        // Unfollow to remove the relationship
        vm.prank(follower);
        graph.unfollow({
            followerAccount: follower,
            accountToUnfollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify isFollowing returns false and follow data is removed
        assertFalse(graph.isFollowing(follower, target), "Should not be following after unfollow");
        vm.expectRevert(Errors.DoesNotExist.selector);
        graph.getFollow(follower, target);
    }

    function test_FollowTimestamp_IsCorrect(address follower, address target, uint56 followTimestamp) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // Warp to a specific timestamp
        vm.warp(followTimestamp);

        // Follow at the specific timestamp
        vm.prank(follower);
        uint256 followId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify follow data has correct timestamp
        Follow memory followData = graph.getFollow(follower, target);
        assertEq(followData.id, followId, "Follow ID should match");
        assertEq(followData.timestamp, followTimestamp, "Follow timestamp should match block timestamp");

        // Warp to a different timestamp and verify the follow timestamp hasn't changed
        vm.warp(uint256(followTimestamp) + 1000);
        Follow memory followDataLater = graph.getFollow(follower, target);
        assertEq(followDataLater.timestamp, followTimestamp, "Follow timestamp should not change");
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override(RulesTest, RuleExecutionTest) {
        IGraph(graphForRules).changeGraphRules(ruleChanges);
    }

    function _primitiveAddress() internal view override returns (address) {
        return graphForRules;
    }

    function _aValidRuleSelector() internal pure override(RulesTest) returns (bytes4) {
        return IGraphRule.processFollow.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = IGraphRule.processFollow.selector;
        selectors[1] = IGraphRule.processUnfollow.selector;
        selectors[2] = IGraphRule.processFollowRuleChanges.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return IGraph(graphForRules).getGraphRules(selector, required);
    }

    function _configureRuleSelector() internal pure override(RulesTest, RuleExecutionTest) returns (bytes4) {
        return IGraphRule.configure.selector;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}

// Graph test split in two to fit within zksync 65535 instruction limit. Some functions copy-pasted (cleanup later)

contract GraphTest2 is RulesTest, BaseDeployments, RuleExecutionTest {
    IGraph graph;

    address sourceAccount = makeAddr("SOURCE");
    address targetAccount = makeAddr("TARGET");
    address graphOwner = makeAddr("GRAPH_OWNER");

    MockAccessControl mockAccessControl;
    address graphForRules;

    function setUp() public override(RulesTest, BaseDeployments, RuleExecutionTest) {
        BaseDeployments.setUp();

        graph = IGraph(
            lensFactory.deployGraph({
                metadataURI: "some metadata uri",
                owner: graphOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        mockAccessControl = new MockAccessControl();

        vm.prank(address(lensFactory));
        graphForRules = graphFactory.deployGraph({
            metadataURI: "uri://graph",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        RulesTest.setUp();
        RuleExecutionTest.setUp();
    }

    function test_MultipleFollows_DifferentAccounts() public {
        address follower = makeAddr("FOLLOWER");
        address[] memory targets = new address[](5);
        uint256[] memory followIds = new uint256[](5);

        // Create target addresses
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = makeAddr(string.concat("TARGET_", vm.toString(i)));
        }

        // Store initial state
        uint256 initialFollowingCount = graph.getFollowingCount(follower);
        uint256[] memory initialFollowersCount = new uint256[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            initialFollowersCount[i] = graph.getFollowersCount(targets[i]);
        }

        // First follow all targets
        for (uint256 i = 0; i < targets.length; i++) {
            vm.prank(follower);
            followIds[i] = graph.follow({
                followerAccount: follower,
                accountToFollow: targets[i],
                customParams: _emptyKeyValueArray(),
                graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
                followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
                extraData: _emptyKeyValueArray()
            });

            // Verify follow relationship
            assertTrue(graph.isFollowing(follower, targets[i]), "Should be following target");
            assertEq(graph.getFollowerById(targets[i], followIds[i]), follower, "Should be able to get follower by ID");
        }

        // Verify state after following all targets
        assertEq(
            graph.getFollowingCount(follower),
            initialFollowingCount + targets.length,
            "Following count should match total targets"
        );
        for (uint256 i = 0; i < targets.length; i++) {
            assertEq(
                graph.getFollowersCount(targets[i]), initialFollowersCount[i] + 1, "Each target should have one follower"
            );
        }

        // Unfollow each target
        for (uint256 i = 0; i < targets.length; i++) {
            vm.prank(follower);
            uint256 unfollowedId = graph.unfollow({
                followerAccount: follower,
                accountToUnfollow: targets[i],
                customParams: _emptyKeyValueArray(),
                graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
            });

            // Verify unfollow
            assertEq(unfollowedId, followIds[i], "Unfollow should return same ID as follow");
            assertFalse(graph.isFollowing(follower, targets[i]), "Should not be following after unfollow");

            // Verify counters
            assertEq(
                graph.getFollowersCount(targets[i]),
                initialFollowersCount[i],
                "Target followers count should decrease to initial"
            );
            assertEq(
                graph.getFollowingCount(follower),
                initialFollowingCount + targets.length - (i + 1),
                "Follower following count should decrease by 1"
            );

            // Verify follow data is removed
            vm.expectRevert(Errors.DoesNotExist.selector);
            graph.getFollow(follower, targets[i]);

            // Verify follower by ID is removed
            vm.expectRevert(Errors.DoesNotExist.selector);
            graph.getFollowerById(targets[i], followIds[i]);
        }

        // Final verification
        assertEq(
            graph.getFollowingCount(follower), initialFollowingCount, "Final following count should be back to initial"
        );
        for (uint256 i = 0; i < targets.length; i++) {
            assertEq(
                graph.getFollowersCount(targets[i]),
                initialFollowersCount[i],
                "Final followers count should be back to initial"
            );
        }
    }

    function test_MultipleFollowers_SingleAccount() public {
        address target = makeAddr("TARGET");
        address[] memory followers = new address[](5);
        uint256[] memory followIds = new uint256[](5);

        // Create follower addresses
        for (uint256 i = 0; i < followers.length; i++) {
            followers[i] = makeAddr(string.concat("FOLLOWER_", vm.toString(i)));
        }

        // Store initial state
        uint256 initialFollowersCount = graph.getFollowersCount(target);
        uint256[] memory initialFollowingCount = new uint256[](followers.length);
        for (uint256 i = 0; i < followers.length; i++) {
            initialFollowingCount[i] = graph.getFollowingCount(followers[i]);
        }

        // Have each follower follow the target
        for (uint256 i = 0; i < followers.length; i++) {
            vm.prank(followers[i]);
            followIds[i] = graph.follow({
                followerAccount: followers[i],
                accountToFollow: target,
                customParams: _emptyKeyValueArray(),
                graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
                followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
                extraData: _emptyKeyValueArray()
            });

            // Verify follow relationship
            assertTrue(graph.isFollowing(followers[i], target), "Should be following target");
            assertEq(graph.getFollowerById(target, followIds[i]), followers[i], "Should be able to get follower by ID");

            // Verify follow data
            Follow memory followData = graph.getFollow(followers[i], target);
            assertEq(followData.id, followIds[i], "Follow ID should match");
            assertEq(followData.timestamp, block.timestamp, "Follow timestamp should be current block");

            // Verify counters
            assertEq(
                graph.getFollowersCount(target),
                initialFollowersCount + i + 1,
                "Target followers count should increase by 1"
            );
            assertEq(
                graph.getFollowingCount(followers[i]),
                initialFollowingCount[i] + 1,
                "Follower following count should increase by 1"
            );
        }

        // Final verification
        assertEq(
            graph.getFollowersCount(target),
            initialFollowersCount + followers.length,
            "Final followers count should match total followers"
        );
        for (uint256 i = 0; i < followers.length; i++) {
            assertEq(
                graph.getFollowingCount(followers[i]),
                initialFollowingCount[i] + 1,
                "Final following count should be increased by 1"
            );
        }
    }

    function test_Follow_Unfollow_Follow_SameAccount(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // Store initial state
        uint256 initialFollowersCount = graph.getFollowersCount(target);
        uint256 initialFollowingCount = graph.getFollowingCount(follower);

        // First follow
        vm.prank(follower);
        uint256 firstFollowId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify first follow
        assertTrue(graph.isFollowing(follower, target), "Should be following after first follow");
        assertEq(graph.getFollowersCount(target), initialFollowersCount + 1, "Followers count should increase");
        assertEq(graph.getFollowingCount(follower), initialFollowingCount + 1, "Following count should increase");

        // Unfollow
        vm.prank(follower);
        uint256 unfollowId = graph.unfollow({
            followerAccount: follower,
            accountToUnfollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify unfollow
        assertFalse(graph.isFollowing(follower, target), "Should not be following after unfollow");
        assertEq(graph.getFollowersCount(target), initialFollowersCount, "Followers count should decrease");
        assertEq(graph.getFollowingCount(follower), initialFollowingCount, "Following count should decrease");
        assertEq(unfollowId, firstFollowId, "Unfollow should return same ID as first follow");

        // Follow again
        vm.prank(follower);
        uint256 secondFollowId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify second follow
        assertTrue(graph.isFollowing(follower, target), "Should be following after second follow");
        assertEq(graph.getFollowersCount(target), initialFollowersCount + 1, "Followers count should increase again");
        assertEq(graph.getFollowingCount(follower), initialFollowingCount + 1, "Following count should increase again");
        assertGt(secondFollowId, firstFollowId, "Second follow ID should be greater than first");

        // Verify follow data
        Follow memory followData = graph.getFollow(follower, target);
        assertEq(followData.id, secondFollowId, "Follow data should have second follow ID");
        assertEq(followData.timestamp, block.timestamp, "Follow timestamp should be current block");
    }

    function test_MultipleUnfollows_SameAccount() public {
        address target = makeAddr("TARGET");
        address[] memory followers = new address[](5);
        uint256[] memory followIds = new uint256[](5);

        // Create follower addresses
        for (uint256 i = 0; i < followers.length; i++) {
            followers[i] = makeAddr(string.concat("FOLLOWER_", vm.toString(i)));
        }

        // Store initial state
        uint256 initialFollowersCount = graph.getFollowersCount(target);
        uint256[] memory initialFollowingCount = new uint256[](followers.length);
        for (uint256 i = 0; i < followers.length; i++) {
            initialFollowingCount[i] = graph.getFollowingCount(followers[i]);
        }

        // Have each follower follow the target
        for (uint256 i = 0; i < followers.length; i++) {
            vm.prank(followers[i]);
            followIds[i] = graph.follow({
                followerAccount: followers[i],
                accountToFollow: target,
                customParams: _emptyKeyValueArray(),
                graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
                followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
                extraData: _emptyKeyValueArray()
            });

            // Verify follow relationship
            assertTrue(graph.isFollowing(followers[i], target), "Should be following target");
            assertEq(graph.getFollowerById(target, followIds[i]), followers[i], "Should be able to get follower by ID");
        }

        // Verify state after all follows
        assertEq(
            graph.getFollowersCount(target),
            initialFollowersCount + followers.length,
            "Target followers count should match total followers"
        );
        for (uint256 i = 0; i < followers.length; i++) {
            assertEq(
                graph.getFollowingCount(followers[i]),
                initialFollowingCount[i] + 1,
                "Each follower's following count should increase by 1"
            );
        }

        // Have each follower unfollow the target
        for (uint256 i = 0; i < followers.length; i++) {
            vm.prank(followers[i]);
            uint256 unfollowedId = graph.unfollow({
                followerAccount: followers[i],
                accountToUnfollow: target,
                customParams: _emptyKeyValueArray(),
                graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
            });

            // Verify unfollow
            assertEq(unfollowedId, followIds[i], "Unfollow should return same ID as follow");
            assertFalse(graph.isFollowing(followers[i], target), "Should not be following after unfollow");

            // Verify counters
            assertEq(
                graph.getFollowersCount(target),
                initialFollowersCount + followers.length - (i + 1),
                "Target followers count should decrease by 1"
            );
            assertEq(
                graph.getFollowingCount(followers[i]),
                initialFollowingCount[i],
                "Follower following count should be back to initial"
            );

            // Verify follow data is removed
            vm.expectRevert(Errors.DoesNotExist.selector);
            graph.getFollow(followers[i], target);

            // Verify follower by ID is removed
            vm.expectRevert(Errors.DoesNotExist.selector);
            graph.getFollowerById(target, followIds[i]);
        }

        // Final verification
        assertEq(
            graph.getFollowersCount(target), initialFollowersCount, "Final followers count should be back to initial"
        );
        for (uint256 i = 0; i < followers.length; i++) {
            assertEq(
                graph.getFollowingCount(followers[i]),
                initialFollowingCount[i],
                "Final following count should be back to initial"
            );
        }
    }

    function test_Follow_WithExtraData(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // Create extra data
        KeyValue[] memory extraData = new KeyValue[](2);
        extraData[0] = KeyValue({key: "referral", value: "friend"});
        extraData[1] = KeyValue({key: "source", value: "mobile_app"});

        // Expect the Follow event with the extra data
        vm.expectEmit(true, true, true, true);
        emit IGraph.Lens_Graph_Followed({
            followerAccount: follower,
            accountToFollow: target,
            followId: 1, // First follow will have ID 1
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            source: address(0),
            extraData: extraData
        });

        // Perform follow operation with extra data
        vm.prank(follower);
        uint256 followId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: extraData
        });

        // Verify basic follow state (extra data is not stored)
        assertTrue(graph.isFollowing(follower, target), "Should be following after follow operation");
        Follow memory followData = graph.getFollow(follower, target);
        assertEq(followData.id, followId, "Follow ID should match");
        assertEq(followData.timestamp, block.timestamp, "Follow timestamp should be current block");
    }

    function test_Follow_WithEmptyExtraData(address follower, address target) public {
        vm.assume(follower != address(0));
        vm.assume(target != address(0));
        vm.assume(follower != target);

        // Expect the Follow event with empty extra data
        vm.expectEmit(true, true, true, true);
        emit IGraph.Lens_Graph_Followed({
            followerAccount: follower,
            accountToFollow: target,
            followId: 1, // First follow will have ID 1
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            source: address(0),
            extraData: _emptyKeyValueArray()
        });

        // Perform follow operation with empty extra data
        vm.prank(follower);
        uint256 followId = graph.follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify basic follow state
        assertTrue(graph.isFollowing(follower, target), "Should be following after follow operation");
        Follow memory followData = graph.getFollow(follower, target);
        assertEq(followData.id, followId, "Follow ID should match");
        assertEq(followData.timestamp, block.timestamp, "Follow timestamp should be current block");
    }

    function test_FollowersCount_MultipleOperations() public {
        address target = makeAddr("TARGET");
        address[] memory followers = new address[](3);
        uint256[] memory followIds = new uint256[](3);

        // Create follower addresses
        for (uint256 i = 0; i < followers.length; i++) {
            followers[i] = makeAddr(string.concat("FOLLOWER_", vm.toString(i)));
        }

        // Store initial state
        uint256 initialFollowersCount = graph.getFollowersCount(target);

        // First wave: All followers follow
        for (uint256 i = 0; i < followers.length; i++) {
            vm.prank(followers[i]);
            followIds[i] = graph.follow({
                followerAccount: followers[i],
                accountToFollow: target,
                customParams: _emptyKeyValueArray(),
                graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
                followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
                extraData: _emptyKeyValueArray()
            });
            assertEq(
                graph.getFollowersCount(target),
                initialFollowersCount + i + 1,
                "Followers count should increase by 1 for each follow"
            );
        }

        // Second wave: First follower unfollows
        vm.prank(followers[0]);
        graph.unfollow({
            followerAccount: followers[0],
            accountToUnfollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
        });
        assertEq(
            graph.getFollowersCount(target), initialFollowersCount + 2, "Followers count should decrease after unfollow"
        );

        // Third wave: First follower follows again
        vm.prank(followers[0]);
        uint256 newFollowId = graph.follow({
            followerAccount: followers[0],
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
        assertEq(
            graph.getFollowersCount(target),
            initialFollowersCount + 3,
            "Followers count should increase after follow again"
        );
        assertGt(newFollowId, followIds[0], "New follow ID should be greater than original");

        // Fourth wave: All followers unfollow
        for (uint256 i = 0; i < followers.length; i++) {
            vm.prank(followers[i]);
            graph.unfollow({
                followerAccount: followers[i],
                accountToUnfollow: target,
                customParams: _emptyKeyValueArray(),
                graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
            });
            assertEq(
                graph.getFollowersCount(target),
                initialFollowersCount + 2 - i,
                "Followers count should decrease by 1 for each unfollow"
            );
        }

        // Final verification
        assertEq(
            graph.getFollowersCount(target),
            initialFollowersCount,
            "Followers count should be back to initial after all operations"
        );
    }

    function test_SetMetadataURI_HasPID(address addressWithPID) public {
        string memory newMetadataURI = "uri://new-metadata-uri";
        assertNotEq(IMetadataBased(address(graphForRules)).getMetadataURI(), newMetadataURI);
        mockAccessControl.mockAccess(
            addressWithPID, address(graphForRules), uint256(keccak256("lens.permission.SetMetadata")), true
        );
        vm.prank(addressWithPID);
        IMetadataBased(address(graphForRules)).setMetadataURI(newMetadataURI);
        assertEq(IMetadataBased(address(graphForRules)).getMetadataURI(), newMetadataURI);
    }

    function test_Cannot_SetMetadataURI_IfDoesNotHavePID(address addressWithoutPID) public {
        string memory oldMetadataURI = IMetadataBased(address(graphForRules)).getMetadataURI();
        string memory newMetadataURI = "uri://new-metadata-uri";
        assertNotEq(oldMetadataURI, newMetadataURI);
        mockAccessControl.mockAccess(
            addressWithoutPID, address(graphForRules), uint256(keccak256("lens.permission.SetMetadata")), false
        );
        vm.prank(addressWithoutPID);
        vm.expectRevert(Errors.AccessDenied.selector);
        IMetadataBased(address(graphForRules)).setMetadataURI(newMetadataURI);
        assertEq(IMetadataBased(address(graphForRules)).getMetadataURI(), oldMetadataURI);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override(RulesTest, RuleExecutionTest) {
        IGraph(graphForRules).changeGraphRules(ruleChanges);
    }

    function _primitiveAddress() internal view override returns (address) {
        return graphForRules;
    }

    function _aValidRuleSelector() internal pure override(RulesTest) returns (bytes4) {
        return IGraphRule.processFollow.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = IGraphRule.processFollow.selector;
        selectors[1] = IGraphRule.processUnfollow.selector;
        selectors[2] = IGraphRule.processFollowRuleChanges.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return IGraph(graphForRules).getGraphRules(selector, required);
    }

    function _configureRuleSelector() internal pure override(RulesTest, RuleExecutionTest) returns (bytes4) {
        return IGraphRule.configure.selector;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testRuleExecution_Follow(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = IGraphRule.processFollow.selector;
        bytes memory executionFunctionCallData = abi.encodeCall(
            IGraph.follow,
            (
                address(this),
                makeAddr("TARGET"),
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyKeyValueArray()
            )
        );
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IGraphRule.processFollow,
            (
                bytes32(uint256(1)),
                address(this),
                address(this),
                makeAddr("TARGET"),
                _emptyKeyValueArray(),
                _emptyKeyValueArray()
            )
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(graphForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_Unfollow(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        IGraph(graphForRules).follow(
            address(this),
            makeAddr("TARGET"),
            _emptyKeyValueArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyKeyValueArray()
        );

        bytes4 executionSelector = IGraphRule.processUnfollow.selector;
        bytes memory executionFunctionCallData = abi.encodeCall(
            IGraph.unfollow,
            (address(this), makeAddr("TARGET"), _emptyKeyValueArray(), _emptyRuleProcessingParamsArray())
        );
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IGraphRule.processUnfollow,
            (
                bytes32(uint256(1)),
                address(this),
                address(this),
                makeAddr("TARGET"),
                _emptyKeyValueArray(),
                _emptyKeyValueArray()
            )
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(graphForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_ProcessFollowRuleChanges(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule1),
            configSalt: bytes32(uint256(0)),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IGraphRule.processFollow.selector, isRequired: true, enabled: true});

        bytes4 executionSelector = IGraphRule.processFollowRuleChanges.selector;

        bytes memory executionFunctionCallData =
            abi.encodeCall(IGraph.changeFollowRules, (address(this), ruleChanges, _emptyRuleProcessingParamsArray()));

        RuleChange[] memory expectedRuleChanges = new RuleChange[](1);
        expectedRuleChanges[0] = ruleChanges[0];
        expectedRuleChanges[0].configSalt = bytes32(uint256(1));

        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IGraphRule.processFollowRuleChanges,
            (bytes32(uint256(1)), address(this), expectedRuleChanges, _emptyKeyValueArray())
        );

        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(graphForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }
}
