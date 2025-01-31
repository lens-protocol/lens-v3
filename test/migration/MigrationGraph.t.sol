// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IGraph, Follow} from "@core/interfaces/IGraph.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";

contract MigrationGraphTest is BaseDeployments {
    IGraph migrationGraph;

    address graphOwner = makeAddr("GRAPH_OWNER");

    function setUp() public override(BaseDeployments) {
        BaseDeployments.switchMigrationMode(true);
        BaseDeployments.setUp();

        migrationGraph = IGraph(
            lensFactory.deployGraph({
                metadataURI: "some metadata uri",
                owner: graphOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );
    }

    function testFollow_withRandomFollowIdandTimestamp(uint256 followId, uint256 timestamp) public {
        vm.assume(followId != 0);

        KeyValue[] memory customParams = new KeyValue[](1);
        customParams[0] = KeyValue(bytes32(0), abi.encode(followId, timestamp));

        uint256 returnedFollowId = migrationGraph.follow({
            followerAccount: makeAddr("FOLLOWER_1"),
            accountToFollow: makeAddr("TARGET_1"),
            customParams: customParams,
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        assertEq(returnedFollowId, followId);
        assertTrue(migrationGraph.isFollowing(makeAddr("FOLLOWER_1"), makeAddr("TARGET_1")));
        assertFalse(migrationGraph.isFollowing(makeAddr("TARGET_1"), makeAddr("FOLLOWER_1")));
        Follow memory follow = migrationGraph.getFollow(makeAddr("FOLLOWER_1"), makeAddr("TARGET_1"));
        assertEq(follow.id, followId);
        assertEq(follow.timestamp, timestamp);
        assertEq(migrationGraph.getFollowersCount(makeAddr("TARGET_1")), 1);
        assertEq(migrationGraph.getFollowingCount(makeAddr("FOLLOWER_1")), 1);
        assertEq(migrationGraph.getFollowerById(makeAddr("TARGET_1"), followId), makeAddr("FOLLOWER_1"));
    }
}
