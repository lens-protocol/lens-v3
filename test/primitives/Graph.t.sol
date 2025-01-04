// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {IAccessControl} from "../../contracts/core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "../../contracts/dashboard/access/OwnerAdminOnlyAccessControl.sol";
import {IGraph} from "../../contracts/core/interfaces/IGraph.sol";
import {Graph} from "../../contracts/core/primitives/graph/Graph.sol";
import "../helpers/TypeHelpers.sol";
import {BaseDeployments} from "./../helpers/BaseDeployments.sol";

contract GraphTest is Test, BaseDeployments {
    IGraph graph;

    address sourceAccount = makeAddr("SOURCE");
    address targetAccount = makeAddr("TARGET");
    address graphOwner = makeAddr("GRAPH_OWNER");

    function setUp() public override {
        super.setUp();

        graph = IGraph(
            lensFactory.deployGraph({
                metadataURI: "some metadata uri",
                owner: graphOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );
    }

    function testFollowAndUnfollow() public {
        vm.prank(sourceAccount);
        graph.follow({
            followerAccount: sourceAccount,
            targetAccount: targetAccount,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        vm.prank(sourceAccount);
        // graph.unfollow(sourceAccount, targetAccount, _emptyExecutionData(), _emptySourceStamp());
        graph.unfollow({
            followerAccount: sourceAccount,
            targetAccount: targetAccount,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }
}
