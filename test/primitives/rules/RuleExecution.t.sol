// SPDX-License-Identiier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "test/helpers/TypeHelpers.sol";
import {Rule, RuleChange, RuleConfigurationChange, RuleSelectorChange, KeyValue} from "@core/types/Types.sol";
import {MockAccessControlLib} from "test/helpers/MockAccessControlLib.sol";
import {MockRule} from "test/mocks/MockRule.sol";
import {Errors} from "@core/types/Errors.sol";

abstract contract RuleExecutionTest is Test {
    function test__RuleExecutionTest() public {
        // Prevents being included in the foundry coverage report
    }

    MockRule rule1;
    MockRule rule2;
    MockRule rule3;
    MockRule rule4;

    function _changeRules(RuleChange[] memory ruleChanges) internal virtual;

    function _configureRuleSelector() internal virtual returns (bytes4);

    function setUp() public virtual {
        rule1 = new MockRule();
        rule2 = new MockRule();
        rule3 = new MockRule();
        rule4 = new MockRule();
    }

    function _verifyRulesExecution(
        bytes4 executionSelector,
        bytes memory expectedRuleExecutionCallData,
        address primitive,
        bytes memory executionFunctionCallData,
        address prankCaller,
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        console.log("mandatory1_passes", mandatory1_passes);
        console.log("mandatory2_passes", mandatory2_passes);
        console.log("optional1_passes", optional1_passes);
        console.log("optional2_passes", optional2_passes);

        RuleChange[] memory ruleChanges = new RuleChange[](4);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule1),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[1] = RuleChange({
            ruleAddress: address(rule2),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[2] = RuleChange({
            ruleAddress: address(rule3),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[3] = RuleChange({
            ruleAddress: address(rule4),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });

        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: executionSelector, isRequired: true, enabled: true});
        ruleChanges[1].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: executionSelector, isRequired: true, enabled: true});
        ruleChanges[2].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: executionSelector, isRequired: false, enabled: true});
        ruleChanges[3].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: executionSelector, isRequired: false, enabled: true});

        if (!mandatory1_passes) {
            rule1.mockToRevertOn(executionSelector);
        }
        if (!mandatory2_passes) {
            rule2.mockToRevertOn(executionSelector);
        }
        if (!optional1_passes) {
            rule3.mockToRevertOn(executionSelector);
        }
        if (!optional2_passes) {
            rule4.mockToRevertOn(executionSelector);
        }

        _changeRules(ruleChanges);

        vm.startPrank(prankCaller);

        if (!(mandatory1_passes && mandatory2_passes)) {
            console.log("expecting revert");
            vm.expectRevert(Errors.RequiredRuleReverted.selector);
        } else if (!(optional1_passes || optional2_passes)) {
            vm.expectRevert(Errors.AllAnyOfRulesReverted.selector);
        }

        vm.expectCall(address(rule1), expectedRuleExecutionCallData);

        (bool success,) = primitive.call(executionFunctionCallData);
        require(success == success); // Dummy require to silence warning.

        vm.stopPrank();
    }
}
