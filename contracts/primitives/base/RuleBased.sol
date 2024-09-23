// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRule} from "./../rules/IRule.sol";
import {RuleConfiguration, RuleExecutionData} from "./../../types/Types.sol";

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

    // keccak256('lens.rule.based.storage') // TODO: Replace this with ruleBased or rule-based or smth
    // TODO: Why again we don't use dynamic keccak here?
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
        // TODO: We don't need msg.sender rn, but it's possible. Maybe we should move this decision into primitive
        _addRule(DEFAULT_RULES_STORAGE_KEY, IRule.DEFAULT_CONFIGURE_SELECTOR, abi.encode(msg.sender), rule);
    }

    function _updateRule(RuleConfiguration memory rule) internal virtual {
        // TODO: We don't need msg.sender rn, but it's possible. Maybe we should move this decision into primitive
        _updateRule(DEFAULT_RULES_STORAGE_KEY, IRule.DEFAULT_CONFIGURE_SELECTOR, abi.encode(msg.sender), rule);
    }

    function _removeRule(address rule) internal virtual {
        _removeRule(DEFAULT_RULES_STORAGE_KEY, rule);
    }

    function _processRules(bytes4 selector, bytes memory primitiveParams, RuleExecutionData calldata userDatas)
        internal
        virtual
    {
        _processRules(DEFAULT_RULES_STORAGE_KEY, selector, primitiveParams, userDatas);
    }

    function _addRule(
        bytes32 ruleStorageKey,
        bytes4 selector,
        bytes memory primitiveData,
        RuleConfiguration memory rule
    ) internal virtual {
        require(!_ruleAlreadySet(ruleStorageKey, rule.ruleAddress), "AddRule: Same rule was already added");
        _addRuleToStorage(ruleStorageKey, rule.ruleAddress, rule.isRequired);
        IRule(rule.ruleAddress).configure(selector, primitiveData, rule.configData);
    }

    function _updateRule(
        bytes32 ruleStorageKey,
        bytes4 selector,
        bytes memory primitiveData,
        RuleConfiguration memory rule
    ) internal virtual {
        require(_ruleAlreadySet(ruleStorageKey, rule.ruleAddress), "ConfigureRule: Rule doesn't exist");
        if ($ruleBasedStorage().rulesStorage[ruleStorageKey].ruleStates[rule.ruleAddress].isRequired != rule.isRequired)
        {
            _removeRuleFromStorage(ruleStorageKey, rule.ruleAddress);
            _addRuleToStorage(ruleStorageKey, rule.ruleAddress, rule.isRequired);
        }
        IRule(rule.ruleAddress).configure(selector, primitiveData, rule.configData);
    }

    function _removeRule(bytes32 ruleStorageKey, address rule) internal virtual {
        require(_ruleAlreadySet(ruleStorageKey, rule), "RuleNotSet");
        _removeRuleFromStorage(ruleStorageKey, rule);
    }

    function _processRules(
        bytes32 ruleStorageKey,
        bytes4 selector,
        bytes memory primitiveParams,
        RuleExecutionData calldata userDatas
    ) internal virtual {
        // Processing AND rules:
        address[] storage requiredRules = _getRulesArray(ruleStorageKey, true);
        for (uint256 i = 0; i < requiredRules.length; i++) {
            IRule(requiredRules[i]).process(selector, primitiveParams, userDatas.dataForRequiredRules[i]);
        }

        // Processing OR rules:
        address[] storage anyOfRules = _getRulesArray(ruleStorageKey, false);
        if (anyOfRules.length == 0) {
            return;
        }
        for (uint256 i = 0; i < anyOfRules.length; i++) {
            (bool success, bytes memory returnData) = anyOfRules[i].call(
                abi.encodeWithSelector(
                    IRule(anyOfRules[i]).process.selector, selector, primitiveParams, userDatas.dataForAnyOfRules[i]
                )
            );
            if (success && abi.decode(returnData, (bool))) {
                return; // If any of the OR rules passed, we can return
            }
        }
        revert("RuleCombinator: None of the OR rules passed");
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
