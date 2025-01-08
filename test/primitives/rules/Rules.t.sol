// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {RuleChange, RuleConfigurationChange, RuleSelectorChange, KeyValue} from "@core/types/Types.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";

abstract contract RulesTest is Test {
    // address author = makeAddr("AUTHOR");
    // address feedOwner = makeAddr("FEED_OWNER");

    MockAccessControl internal _accessControl;

    function setUp() public {
        _accessControl = new MockAccessControl();
    }

    function test_Cannot_ChangeRules_IfNotHasAccessToChangeRulesPid() public {
        // Mock Access Control to disallow changing rules
        uint256 changeRulesPid = uint256(keccak256("lens.permission.ChangeRules"));
        _accessControl.mockAccess({
            account: address(this),
            contractAddress: _primitiveAddress(),
            permissionId: changeRulesPid,
            access: false
        });

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(this),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](0)
        });

        _beforeChangeRules(ruleChanges);

        _changeRules(ruleChanges);
    }

    function _beforeChangeRules(RuleChange[] memory ruleChanges) internal virtual;

    function _changeRules(RuleChange[] memory ruleChanges) internal virtual;

    function _primitiveAddress() internal virtual returns (address);
}
