// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRule} from "./../rules/IRule.sol";
import {RuleConfiguration} from "./../../types/Types.sol";

contract RuleBased {
    struct RuleState {
        uint8 index;
        bool isRequired;
        bool isSet;
    }

    struct RulesStorage {
        address[] requiredRules;
        address[] anyOfRules;
        mapping(address => RuleState) ruleStates;
    }

    struct RuleBasedStorage {
        mapping(bytes32 => RulesStorage) rulesStorage;
    }

    // keccak256('lens.rule.based.storage')
    bytes32 constant RULE_BASED_STORAGE_SLOT = 0x78c2efc16b0e28b79e7018ec8a12d1eec1218d52bcd7993a02f6763876b0ceb6;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := RULE_BASED_STORAGE_SLOT
        }
    }

    bytes32 private immutable DEFAULT_RULES_STORAGE_KEY;

    constructor(bytes32 defaultRulesStorageKey) {
        DEFAULT_RULES_STORAGE_KEY = defaultRulesStorageKey;
    }

    // Internal

    function _addRule(RuleConfiguration memory rule) internal virtual {
        _addDefaultRule(DEFAULT_RULES_STORAGE_KEY, rule);
    }

    function _updateRule(RuleConfiguration memory rule) internal virtual {
        _updateDefaultRule(DEFAULT_RULES_STORAGE_KEY, rule);
    }

    function _removeRule(address rule) internal virtual {
        _removeRule(DEFAULT_RULES_STORAGE_KEY, rule);
    }

    function _processRules(bytes[] memory datas) internal virtual {
        _processRules(DEFAULT_RULES_STORAGE_KEY, datas);
    }

    function _addRule(bytes32 ruleStorageKey, RuleConfiguration memory rule, bytes memory encodedConfigureCall)
        internal
        virtual
    {
        require(!_ruleAlreadySet(ruleStorageKey, rule.ruleAddress), "AddRule: Same rule was already added");
        _addRuleToStorage(ruleStorageKey, rule.ruleAddress, rule.isRequired);
        (bool success,) = rule.ruleAddress.call(encodedConfigureCall);
        require(success, "AddRule: Rule configuration failed");
    }

    function _addDefaultRule(bytes32 ruleStorageKey, RuleConfiguration memory rule) private {
        require(!_ruleAlreadySet(ruleStorageKey, rule.ruleAddress), "AddRule: Same rule was already added");
        _addRuleToStorage(ruleStorageKey, rule.ruleAddress, rule.isRequired);
        IRule(rule.ruleAddress).configure(rule.configData);
    }

    function _updateRule(bytes32 ruleStorageKey, RuleConfiguration memory rule, bytes memory encodedCall)
        internal
        virtual
    {
        require(_ruleAlreadySet(ruleStorageKey, rule.ruleAddress), "ConfigureRule: Rule doesn't exist");
        if ($ruleBasedStorage().rulesStorage[ruleStorageKey].ruleStates[rule.ruleAddress].isRequired != rule.isRequired)
        {
            _removeRuleFromStorage(ruleStorageKey, rule.ruleAddress);
            _addRuleToStorage(ruleStorageKey, rule.ruleAddress, rule.isRequired);
        }
        (bool success,) = rule.ruleAddress.call(encodedCall);
        require(success, "AddRule: Rule configuration failed");
    }

    function _updateDefaultRule(bytes32 ruleStorageKey, RuleConfiguration memory rule) private {
        require(_ruleAlreadySet(ruleStorageKey, rule.ruleAddress), "ConfigureRule: Rule doesn't exist");
        if ($ruleBasedStorage().rulesStorage[ruleStorageKey].ruleStates[rule.ruleAddress].isRequired != rule.isRequired)
        {
            _removeRuleFromStorage(ruleStorageKey, rule.ruleAddress);
            _addRuleToStorage(ruleStorageKey, rule.ruleAddress, rule.isRequired);
        }
        IRule(rule.ruleAddress).configure(rule.configData);
    }

    function _removeRule(bytes32 ruleStorageKey, address rule) internal virtual {
        require(_ruleAlreadySet(ruleStorageKey, rule), "RuleNotSet");
        _removeRuleFromStorage(ruleStorageKey, rule);
    }

    function _processRules(bytes32 ruleStorageKey, bytes[] memory encodedCall) internal virtual {
        // Processing AND rules:
        address[] storage requiredRules = _getRulesArray(ruleStorageKey, true);
        for (uint256 i = 0; i < requiredRules.length; i++) {
            (bool callNotReverted,) = requiredRules[i].call(encodedCall[i]);
            require(callNotReverted, "RuleCombinator: Some required rule failed");
        }
        // Processing OR rules:
        address[] storage anyOfRules = _getRulesArray(ruleStorageKey, false);
        for (uint256 i = requiredRules.length; i < requiredRules.length + anyOfRules.length; i++) {
            (bool success, bytes memory returnData) = anyOfRules[i].call(encodedCall[i]);
            if (success && abi.decode(returnData, (bool))) {
                return; // If any of the rules passed, we can return
            }
        }
        revert("RuleCombinator: All of the OR rules failed");
    }

    // Private

    function _addRuleToStorage(bytes32 ruleStorageKey, address ruleAddress, bool requiredRule) private {
        address[] storage rules = _getRulesArray(ruleStorageKey, requiredRule);
        uint8 index = uint8(rules.length); // TODO: Add a check if needed
        rules.push(ruleAddress);
        $ruleBasedStorage().rulesStorage[ruleStorageKey].ruleStates[ruleAddress] =
            RuleState({index: index, isRequired: requiredRule, isSet: true});
    }

    function _removeRuleFromStorage(bytes32 ruleStorageKey, address ruleAddress) private {
        uint8 index = $ruleBasedStorage().rulesStorage[ruleStorageKey].ruleStates[ruleAddress].index;
        address[] storage rules = _getRulesArray(
            ruleStorageKey, $ruleBasedStorage().rulesStorage[ruleStorageKey].ruleStates[ruleAddress].isRequired
        );
        if (rules.length > 1) {
            // Copy the last element in the array into the index of the rule to delete
            rules[index] = rules[rules.length - 1];
            // Set the proper index for the swapped rule
            $ruleBasedStorage().rulesStorage[ruleStorageKey].ruleStates[rules[index]].index = index;
        }
        rules.pop();
        delete $ruleBasedStorage().rulesStorage[ruleStorageKey].ruleStates[ruleAddress];
    }

    function _ruleAlreadySet(bytes32 ruleStorageKey, address rule) private view returns (bool) {
        return $ruleBasedStorage().rulesStorage[ruleStorageKey].ruleStates[rule].isSet;
    }

    function _getRulesArray(bool requiredRules) internal view returns (address[] storage) {
        return _getRulesArray(DEFAULT_RULES_STORAGE_KEY, requiredRules);
    }

    function _getRulesArray(bytes32 ruleStorageKey, bool requiredRules) internal view returns (address[] storage) {
        return requiredRules
            ? $ruleBasedStorage().rulesStorage[ruleStorageKey].requiredRules
            : $ruleBasedStorage().rulesStorage[ruleStorageKey].anyOfRules;
    }
}
