// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "@extensions/access/OwnerAdminOnlyAccessControl.sol";
import {IGraph} from "@core/interfaces/IGraph.sol";
import {Graph} from "@core/primitives/graph/Graph.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";
import {Rule} from "@core/types/Types.sol";
import {IGraphRule} from "@core/interfaces/IGraphRule.sol";

contract GraphTest is RulesTest, BaseDeployments {
    IGraph graph;

    address sourceAccount = makeAddr("SOURCE");
    address targetAccount = makeAddr("TARGET");
    address graphOwner = makeAddr("GRAPH_OWNER");

    MockAccessControl mockAccessControl;
    address graphForRules;

    function setUp() public override(RulesTest, BaseDeployments) {
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

        graphForRules = graphFactory.deployGraph({
            metadataURI: "uri://graph",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        RulesTest.setUp();
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

        RulesTest.setUp();
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override {
        IGraph(graphForRules).changeGraphRules(ruleChanges);
    }

    function _primitiveAddress() internal view override returns (address) {
        return graphForRules;
    }

    function _aValidRuleSelector() internal pure override returns (bytes4) {
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
}
