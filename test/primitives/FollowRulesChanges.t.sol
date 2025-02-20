// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../helpers/TypeHelpers.sol";
import {IGraph} from "@core/interfaces/IGraph.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {Rule, RuleConfigurationChange, RuleSelectorChange} from "@core/types/Types.sol";
import {IFollowRule} from "@core/interfaces/IFollowRule.sol";
import {Errors} from "@core/types/Errors.sol";
import {RuleExecutionTest} from "test/primitives/rules/RuleExecution.t.sol";

contract FollowRulesChangesTest is RulesTest, BaseDeployments, RuleExecutionTest {
    address graphForRules;
    MockAccessControl mockAccessControl;

    function setUp() public virtual override(RulesTest, BaseDeployments, RuleExecutionTest) {
        BaseDeployments.setUp();

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

    function test_Cannot_ChangeRules_IfNotHasAccessToChangeRulesPid() public override(RulesTest) {}

    function test_Cannot_ChangeRules_DisableSelectorThatIsNotEnabled() public override(RulesTest) {
        bytes4 selector = _getPrimitiveSupportedRuleSelectors()[0];

        RuleChange[] memory ruleChanges = new RuleChange[](1);

        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(1)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: false});

        vm.expectRevert(Errors.RedundantStateChange.selector);
        _changeRules(ruleChanges);
    }

    function _changeRules(RuleChange[] memory ruleChanges) internal override(RulesTest, RuleExecutionTest) {
        IGraph(graphForRules).changeFollowRules(address(this), ruleChanges, _emptyRuleProcessingParamsArray());
    }

    function _primitiveAddress() internal view override returns (address) {
        return graphForRules;
    }

    function _aValidRuleSelector() internal pure override returns (bytes4) {
        return IFollowRule.processFollow.selector;
    }

    function _configureRuleSelector() internal pure override(RulesTest, RuleExecutionTest) returns (bytes4) {
        return IFollowRule.configure.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IFollowRule.processFollow.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return IGraph(graphForRules).getFollowRules(address(this), selector, required);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testRuleExecution_FollowEntityRules(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = IFollowRule.processFollow.selector;
        bytes memory executionFunctionCallData = abi.encodeCall(
            IGraph.follow,
            (
                makeAddr("TARGET"),
                address(this),
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyKeyValueArray()
            )
        );
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IFollowRule.processFollow,
            (
                bytes32(uint256(1)),
                makeAddr("TARGET"),
                makeAddr("TARGET"),
                address(this),
                _emptyKeyValueArray(),
                _emptyKeyValueArray()
            )
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(graphForRules),
            executionFunctionCallData,
            makeAddr("TARGET"),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }
}
