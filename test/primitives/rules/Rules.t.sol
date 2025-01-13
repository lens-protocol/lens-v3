// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Rule, RuleChange, RuleConfigurationChange, RuleSelectorChange, KeyValue} from "@core/types/Types.sol";
import {MockAccessControlLib} from "test/helpers/MockAccessControlLib.sol";
import {MockRule, IPrimitiveRule} from "test/mocks/MockRule.sol";
import {Errors} from "@core/types/Errors.sol";

abstract contract RulesTest is Test {
    function _changeRules(RuleChange[] memory ruleChanges) internal virtual;

    function _primitiveAddress() internal virtual returns (address);

    function _aValidRuleSelector() internal virtual returns (bytes4);

    function _getPrimitiveSupportedRuleSelectors() internal virtual returns (bytes4[] memory);

    function _getPrimitiveRules(bytes4 selector, bool required) internal virtual returns (Rule[] memory);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    using MockAccessControlLib for address;

    uint256 PID__CHANGE_RULES = uint256(keccak256("lens.permission.ChangeRules"));

    MockRule rule;
    MockRule otherRule;

    function setUp() public virtual {
        rule = new MockRule();
        otherRule = new MockRule();

        // Mock Access Control to allow changing rules by default

        _primitiveAddress().mockAccess({
            account: address(this),
            contractAddress: _primitiveAddress(),
            permissionId: PID__CHANGE_RULES,
            access: true
        });
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_ChangeRules() public {
        bytes4 selector = _aValidRuleSelector();

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: true});

        _changeRules(ruleChanges);

        bytes4[] memory selectors = _getPrimitiveSupportedRuleSelectors();
        for (uint256 i = 0; i < selectors.length; i++) {
            if (selectors[i] == selector) {
                assertEq(1, _getPrimitiveRules(selectors[i], true).length);
                assertEq(0, _getPrimitiveRules(selectors[i], false).length);
            } else {
                assertEq(0, _getPrimitiveRules(selectors[i], true).length);
                assertEq(0, _getPrimitiveRules(selectors[i], false).length);
            }
        }
    }

    function test_ChangeRules_Reconfigure() public {
        return; // TODO: Implement
    }

    function test_Cannot_ChangeRules_EnableSelectorForUnconfiguredRule() public {
        return; // TODO: Implement
    }

    function test_Cannot_ChangeRules_IfNotHasAccessToChangeRulesPid() public {
        // Mock Access Control to disallow changing rules
        _primitiveAddress().mockAccess({
            account: address(this),
            contractAddress: _primitiveAddress(),
            permissionId: PID__CHANGE_RULES,
            access: false
        });

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](0)
        });

        vm.expectRevert(Errors.AccessDenied.selector);
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_IfNonZeroConfigSaltIsPassed_ForARuleThatWasNotConfiguredYet() public {
        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(bytes2(0x5A17)),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](0)
        });

        vm.expectRevert(Errors.InvalidConfigSalt.selector);
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_IfSelectorNotAllowed() public {
        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: bytes4(0x12345678), isRequired: true, enabled: true});

        vm.expectRevert(Errors.UnsupportedSelector.selector);
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_IfConfigureCallReverts() public {
        rule.mockToRevertOn(IPrimitiveRule.configure.selector);
        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: _aValidRuleSelector(), isRequired: true, enabled: true});

        vm.expectRevert(Errors.ConfigureCallReverted.selector);
        _changeRules(ruleChanges);
    }
}
