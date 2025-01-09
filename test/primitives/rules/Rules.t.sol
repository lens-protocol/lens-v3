// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {RuleChange, RuleConfigurationChange, RuleSelectorChange, KeyValue} from "@core/types/Types.sol";
import {MockAccessControlLib} from "test/helpers/MockAccessControlLib.sol";
import {MockRule, IPrimitiveRule} from "test/mocks/MockRule.sol";

abstract contract RulesTest is Test {
    using MockAccessControlLib for address;

    MockRule rule = new MockRule();
    MockRule otherRule = new MockRule();

    function test_ChangeRules() public {
        // Mock Access Control to allow changing rules
        uint256 changeRulesPid = uint256(keccak256("lens.permission.ChangeRules"));
        _primitiveAddress().mockAccess({
            account: address(this),
            contractAddress: _primitiveAddress(),
            permissionId: changeRulesPid,
            access: true
        });

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: _aValidSelector(), isRequired: true, enabled: true});

        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_IfNotHasAccessToChangeRulesPid() public {
        // Mock Access Control to disallow changing rules
        uint256 changeRulesPid = uint256(keccak256("lens.permission.ChangeRules"));
        _primitiveAddress().mockAccess({
            account: address(this),
            contractAddress: _primitiveAddress(),
            permissionId: changeRulesPid,
            access: false
        });

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](0)
        });

        vm.expectRevert();
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_IfNonZeroConfigSaltIsPassed_ForARuleThatWasNotConfiguredYet() public {
        // Mock Access Control to allow changing rules
        uint256 changeRulesPid = uint256(keccak256("lens.permission.ChangeRules"));
        _primitiveAddress().mockAccess({
            account: address(this),
            contractAddress: _primitiveAddress(),
            permissionId: changeRulesPid,
            access: true
        });

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(bytes2(0x5A17)),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](0)
        });

        vm.expectRevert();
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_IfSelectorNotAllowed() public {
        // Mock Access Control to allow changing rules
        uint256 changeRulesPid = uint256(keccak256("lens.permission.ChangeRules"));
        _primitiveAddress().mockAccess({
            account: address(this),
            contractAddress: _primitiveAddress(),
            permissionId: changeRulesPid,
            access: true
        });

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: bytes4(0x12345678), isRequired: true, enabled: true});

        vm.expectRevert();
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_IfConfigureCallReverts() public {
        // Mock Access Control to allow changing rules
        uint256 changeRulesPid = uint256(keccak256("lens.permission.ChangeRules"));
        _primitiveAddress().mockAccess({
            account: address(this),
            contractAddress: _primitiveAddress(),
            permissionId: changeRulesPid,
            access: true
        });

        rule.mockToRevertOn(IPrimitiveRule.configure.selector);
        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: _aValidSelector(), isRequired: true, enabled: true});

        vm.expectRevert();
        _changeRules(ruleChanges);
    }

    function _changeRules(RuleChange[] memory ruleChanges) internal virtual;

    function _primitiveAddress() internal virtual returns (address);

    function _aValidSelector() internal virtual returns (bytes4);
}
