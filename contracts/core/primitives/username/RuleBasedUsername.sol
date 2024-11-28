// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IUsernameRule} from "./../../interfaces/IUsernameRule.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {RuleConfiguration, RuleExecutionData} from "./../../types/Types.sol";

contract RuleBasedUsername {
    using RulesLib for RulesStorage;

    struct RuleBasedStorage {
        RulesStorage usernameRulesStorage;
    }

    // keccak256('lens.rule.based.username.storage')
    bytes32 constant RULE_BASED_USERNAME_STORAGE_SLOT =
        0xdb7398dc7b1d4544bdce6830d22802260c007b71c45e9fa93889a6ec0667be87;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := RULE_BASED_USERNAME_STORAGE_SLOT
        }
    }

    function $usernameRulesStorage() private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().usernameRulesStorage;
    }

    // Internal

    function _addUsernameRule(RuleConfiguration memory rule) internal {
        $usernameRulesStorage().addRule(rule, abi.encodeCall(IUsernameRule.configure, (rule.configData)));
    }

    function _updateUsernameRule(RuleConfiguration memory rule) internal {
        $usernameRulesStorage().updateRule(rule, abi.encodeCall(IUsernameRule.configure, (rule.configData)));
    }

    function _removeUsernameRule(address rule) internal {
        $usernameRulesStorage().removeRule(rule);
    }

    function _internalProcessCreation(
        address rule,
        address account,
        string calldata username,
        bytes calldata data
    ) internal returns (bool, bytes memory) {
        return rule.call(abi.encodeCall(IUsernameRule.processCreation, (account, username, data)));
    }

    function _processCreation(address account, string calldata username, RuleExecutionData calldata data) internal {
        _processUsernameRule(_internalProcessCreation, account, username, data);
    }

    function _internalProcessAssigning(
        address rule,
        address account,
        string calldata username,
        bytes calldata data
    ) internal returns (bool, bytes memory) {
        return rule.call(abi.encodeCall(IUsernameRule.processAssigning, (account, username, data)));
    }

    function _processAssigning(address account, string calldata username, RuleExecutionData calldata data) internal {
        _processUsernameRule(_internalProcessAssigning, account, username, data);
    }

    function _processUsernameRule(
        function(address,address,string calldata,bytes calldata) internal returns(bool, bytes memory) func,
        address account,
        string calldata username,
        RuleExecutionData calldata data
    ) private {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $usernameRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) =
                func($usernameRulesStorage().anyOfRules[i], account, username, data.dataForRequiredRules[i]);
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($usernameRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $usernameRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) =
                func($usernameRulesStorage().anyOfRules[i], account, username, data.dataForAnyOfRules[i]);

            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the any-of rules failed");
    }

    function _getUsernameRules(bool isRequired) internal view returns (address[] memory) {
        return $usernameRulesStorage().getRulesArray(isRequired);
    }
}
