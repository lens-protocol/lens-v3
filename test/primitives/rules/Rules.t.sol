// SPDX-License-Identiier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "test/helpers/TypeHelpers.sol";
import {Rule, RuleChange, RuleConfigurationChange, RuleSelectorChange, KeyValue} from "@core/types/Types.sol";
import {MockAccessControlLib} from "test/helpers/MockAccessControlLib.sol";
import {MockRule} from "test/mocks/MockRule.sol";
import {Errors} from "@core/types/Errors.sol";

abstract contract RulesTest is Test {
    function _changeRules(RuleChange[] memory ruleChanges) internal virtual;

    function _primitiveAddress() internal virtual returns (address);

    function _aValidRuleSelector() internal virtual returns (bytes4);

    function _getPrimitiveSupportedRuleSelectors() internal virtual returns (bytes4[] memory);

    function _getPrimitiveRules(bytes4 selector, bool required) internal virtual returns (Rule[] memory);

    function _configureRuleSelector() internal virtual returns (bytes4);

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

    function test_ChangeRules_Configure() public {
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
        bytes4 selector = _aValidRuleSelector();

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: true});

        assertEq(0, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);

        _changeRules(ruleChanges);

        assertEq(1, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);

        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(1)),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: _emptyRuleSelectorChangeArray()
        });

        _changeRules(ruleChanges);

        assertEq(1, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);
    }

    function test_ChangeRules_ConvertAnyOfToRequiredRule() public {
        bytes4 selector = _aValidRuleSelector();

        RuleChange[] memory ruleChanges = new RuleChange[](2);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: true});
        ruleChanges[1] = ruleChanges[0];

        assertEq(0, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);

        _changeRules(ruleChanges);

        assertEq(0, _getPrimitiveRules(selector, true).length);
        assertEq(2, _getPrimitiveRules(selector, false).length);

        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(1)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](2)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: false});
        ruleChanges[0].selectorChanges[1] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: true});
        ruleChanges[1] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(2)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](2)
        });
        ruleChanges[1].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: false});
        ruleChanges[1].selectorChanges[1] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: true});

        _changeRules(ruleChanges);

        assertEq(2, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);
    }

    function test_ChangeRules_ConvertRequiredToAnyOfRule() public {
        bytes4 selector = _aValidRuleSelector();

        RuleChange[] memory ruleChanges = new RuleChange[](2);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: true});
        ruleChanges[1] = ruleChanges[0];

        assertEq(0, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);

        _changeRules(ruleChanges);

        assertEq(2, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);

        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(1)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](2)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: false});
        ruleChanges[0].selectorChanges[1] =
            RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: true});
        ruleChanges[1] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(2)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](2)
        });
        ruleChanges[1].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: false});
        ruleChanges[1].selectorChanges[1] =
            RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: true});

        _changeRules(ruleChanges);

        assertEq(0, _getPrimitiveRules(selector, true).length);
        assertEq(2, _getPrimitiveRules(selector, false).length);
    }

    function test_Cannot_ChangeRules_EnableSelectorForUnconfiguredRule() public {
        bytes4 selector = _aValidRuleSelector();

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: true});

        vm.expectRevert(Errors.RuleNotConfigured.selector);
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_DisableSelectorForUnconfiguredRule() public {
        bytes4 selector = _aValidRuleSelector();

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: false});

        vm.expectRevert(Errors.RedundantStateChange.selector);
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_DisableSelectorThatIsAlreadyDisabled() public {
        bytes4 selector = _aValidRuleSelector();

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: false});

        vm.expectRevert(Errors.RedundantStateChange.selector);
        _changeRules(ruleChanges);
    }

    // function test_Cannot_ChangeRules_SettingASingleRuleAsAnyOfRule() public {
    //     bytes4 selector = _aValidRuleSelector();

    //     RuleChange[] memory ruleChanges = new RuleChange[](1);
    //     ruleChanges[0] = RuleChange({
    //         ruleAddress: address(rule),
    //         configSalt: bytes32(0),
    //         configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
    //         selectorChanges: new RuleSelectorChange[](1)
    //     });
    //     ruleChanges[0].selectorChanges[0] =
    //         RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: true});

    //     // Ensure has zero anyOf rules before applying the rule changes
    //     assertEq(0, _getPrimitiveRules(selector, false).length);

    //     vm.expectRevert(Errors.SingleAnyOfRule.selector);
    //     _changeRules(ruleChanges);
    // }

    // function test_Cannot_ChangeRules_IfFinalStateHasSingleAnyOfRule() public {
    //     bytes4 selector = _aValidRuleSelector();

    //     // Ensure has zero anyOf rules before applying the rule changes
    //     assertEq(0, _getPrimitiveRules(selector, false).length);

    //     RuleChange[] memory ruleChanges = new RuleChange[](3);
    //     ruleChanges[0] = RuleChange({
    //         ruleAddress: address(rule),
    //         configSalt: bytes32(0),
    //         configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
    //         selectorChanges: new RuleSelectorChange[](1)
    //     });
    //     ruleChanges[0].selectorChanges[0] =
    //         RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: true});
    //     ruleChanges[1] = ruleChanges[0];
    //     ruleChanges[2] = ruleChanges[0];

    //     // Ensure has zero anyOf rules before applying the rule changes
    //     assertEq(0, _getPrimitiveRules(selector, false).length);

    //     _changeRules(ruleChanges);
    //     // Ensure has three anyOf rules after applying the first rule changes
    //     assertEq(3, _getPrimitiveRules(selector, false).length);

    //     ruleChanges = new RuleChange[](2);
    //     ruleChanges[0] = RuleChange({
    //         ruleAddress: address(rule),
    //         configSalt: bytes32(uint256(1)),
    //         configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
    //         selectorChanges: new RuleSelectorChange[](1)
    //     });
    //     ruleChanges[0].selectorChanges[0] =
    //         RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: false});
    //     ruleChanges[1] = RuleChange({
    //         ruleAddress: address(rule),
    //         configSalt: bytes32(uint256(3)),
    //         configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
    //         selectorChanges: new RuleSelectorChange[](1)
    //     });
    //     ruleChanges[1].selectorChanges[0] =
    //         RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: false});

    //     vm.expectRevert(Errors.SingleAnyOfRule.selector);
    //     _changeRules(ruleChanges);
    // }

    function test_Cannot_ChangeRules_IfTotalAmountOfRulesIsExceeded() public {
        bytes4 selector = _aValidRuleSelector();

        uint256 maxAmountOfRules = 20;

        RuleChange[] memory ruleChanges = new RuleChange[](maxAmountOfRules);

        for (uint256 i = 0; i < ruleChanges.length; i++) {
            ruleChanges[i] = RuleChange({
                ruleAddress: address(rule),
                configSalt: bytes32(0),
                configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
                selectorChanges: new RuleSelectorChange[](1)
            });
            ruleChanges[i].selectorChanges[0] =
                RuleSelectorChange({ruleSelector: selector, isRequired: i % 2 == 0, enabled: true});
        }

        // Ensure has zero rules before applying the rule changes
        assertEq(0, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);

        _changeRules(ruleChanges);

        // Ensure has three anyOf rules after applying the first rule changes
        uint256 amountOfRules = _getPrimitiveRules(selector, false).length + _getPrimitiveRules(selector, true).length;
        assertEq(maxAmountOfRules, amountOfRules);

        ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: true});

        vm.expectRevert(Errors.LimitReached.selector);
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_IfNotHasAccessToChangeRulesPid() public virtual {
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
        rule.mockToRevertOn(_configureRuleSelector());
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

    function test_Cannot_ChangeRules_IfSwitchingAnEnabledSelectorFromAnyOfToRequiredInASingleSelectorChange() public {
        bytes4 selector = _aValidRuleSelector();

        RuleChange[] memory ruleChanges = new RuleChange[](2);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: true});
        ruleChanges[1] = ruleChanges[0];

        assertEq(0, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);

        _changeRules(ruleChanges);

        assertEq(0, _getPrimitiveRules(selector, true).length);
        assertEq(2, _getPrimitiveRules(selector, false).length);

        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(1)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: true});
        ruleChanges[1] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(2)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[1].selectorChanges[0] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: true});

        vm.expectRevert(Errors.SelectorEnabledForDifferentRuleType.selector);
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_IfSwitchingAnEnabledSelectorFromRequiredToAnyOfInASingleSelectorChange() public {
        bytes4 selector = _aValidRuleSelector();

        RuleChange[] memory ruleChanges = new RuleChange[](2);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: true});
        ruleChanges[1] = ruleChanges[0];

        assertEq(0, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);

        _changeRules(ruleChanges);

        assertEq(2, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);

        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(1)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: true});
        ruleChanges[1] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(2)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[1].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: true});

        vm.expectRevert(Errors.SelectorEnabledForDifferentRuleType.selector);
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_DisableSelectorThatIsNotEnabled() public virtual {
        bytes4 enabledSelector = _getPrimitiveSupportedRuleSelectors()[0];
        bytes4 disabledSelector = _getPrimitiveSupportedRuleSelectors()[1];

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: enabledSelector, isRequired: true, enabled: true});

        _changeRules(ruleChanges);

        assertEq(1, _getPrimitiveRules(enabledSelector, true).length);
        assertEq(0, _getPrimitiveRules(enabledSelector, false).length);
        assertEq(0, _getPrimitiveRules(disabledSelector, true).length);
        assertEq(0, _getPrimitiveRules(disabledSelector, false).length);

        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(1)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: disabledSelector, isRequired: true, enabled: false});

        vm.expectRevert(Errors.RedundantStateChange.selector);
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_DisableSelectorOnRequiredRulesThatIsEnabledForAnyOfRules() public {
        bytes4 selector = _aValidRuleSelector();

        RuleChange[] memory ruleChanges = new RuleChange[](2);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: true});
        ruleChanges[1] = ruleChanges[0];

        _changeRules(ruleChanges);

        assertEq(0, _getPrimitiveRules(selector, true).length);
        assertEq(2, _getPrimitiveRules(selector, false).length);

        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(1)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: false});
        ruleChanges[1] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(2)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[1].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: false});

        vm.expectRevert(Errors.SelectorEnabledForDifferentRuleType.selector);
        _changeRules(ruleChanges);
    }

    function test_Cannot_ChangeRules_DisableSelectorOnAnyOfRulesThatIsEnabledForRequiredRules() public {
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

        assertEq(1, _getPrimitiveRules(selector, true).length);
        assertEq(0, _getPrimitiveRules(selector, false).length);

        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(uint256(1)),
            configurationChanges: RuleConfigurationChange({configure: false, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: false});

        vm.expectRevert(Errors.SelectorEnabledForDifferentRuleType.selector);
        _changeRules(ruleChanges);
    }
}
