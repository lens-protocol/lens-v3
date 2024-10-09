// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUsernameRule} from "./IUsernameRule.sol";
import {RulesStorage, RulesLib} from "./../base/RulesLib.sol";
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

    function _addUsernameRule(RuleConfiguration calldata rule) internal {
        $usernameRulesStorage().addRule(rule, abi.encodeWithSelector(IUsernameRule.configure.selector, rule.configData));
    }

    function _updateUsernameRule(RuleConfiguration calldata rule) internal {
        $usernameRulesStorage().updateRule(
            rule, abi.encodeWithSelector(IUsernameRule.configure.selector, rule.configData)
        );
    }

    function _removeUsernameRule(address rule) internal {
        $usernameRulesStorage().removeRule(rule);
    }

    function _processRegistering(address account, string memory username, RuleExecutionData calldata data) internal {
        _processUsernameRule(IUsernameRule.processRegistering.selector, account, username, data);
    }

    function _processUnregistering(address account, string memory username, RuleExecutionData calldata data) internal {
        _processUsernameRule(IUsernameRule.processUnregistering.selector, account, username, data);
    }

    function _processUsernameRule(
        bytes4 selector,
        address account,
        string memory username,
        RuleExecutionData calldata data
    ) private {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $usernameRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $usernameRulesStorage().requiredRules[i].call(
                abi.encodeWithSelector(selector, account, username, data.dataForRequiredRules[i])
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($usernameRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $usernameRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $usernameRulesStorage().anyOfRules[i].call(
                abi.encodeWithSelector(selector, account, username, data.dataForAnyOfRules[i])
            );
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
