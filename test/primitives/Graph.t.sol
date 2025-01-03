// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {IAccessControl} from "../../contracts/core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "../../contracts/dashboard/access/OwnerAdminOnlyAccessControl.sol";
import {IGraph} from "../../contracts/core/interfaces/IGraph.sol";
import {Graph} from "../../contracts/core/primitives/graph/Graph.sol";
import "../helpers/TypeHelpers.sol";

contract GraphTest is Test {
    IAccessControl accessControl;
    IGraph graph;

    address sourceAccount = makeAddr("SOURCE");
    address targetAccount = makeAddr("TARGET");

    function setUp() public {
        accessControl = new OwnerAdminOnlyAccessControl(address(this));
        graph = new Graph({metadataURI: "uri://graph-metadata", accessControl: IAccessControl(accessControl)});
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
