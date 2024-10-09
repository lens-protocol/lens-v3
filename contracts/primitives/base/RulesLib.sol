// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RuleConfiguration} from "./../../types/Types.sol";

struct RulesStorage {
    address[] requiredRules;
    address[] anyOfRules;
    mapping(address => RuleState) ruleStates;
}

struct RuleState {
    uint8 index;
    bool isRequired;
    bool isSet;
}

library RulesLib {
    function addRule(RulesStorage storage ruleStorage, RuleConfiguration memory rule, bytes memory encodedConfigureCall)
        internal
    {
        require(!_ruleAlreadySet(ruleStorage, rule.ruleAddress), "AddRule: Same rule was already added");
        _addRuleToStorage(ruleStorage, rule.ruleAddress, rule.isRequired);
        (bool success,) = rule.ruleAddress.call(encodedConfigureCall);
        require(success, "AddRule: Rule configuration failed");
    }

    function updateRule(RulesStorage storage ruleStorage, RuleConfiguration memory rule, bytes memory encodedCall)
        internal
    {
        require(_ruleAlreadySet(ruleStorage, rule.ruleAddress), "ConfigureRule: Rule doesn't exist");
        if (ruleStorage.ruleStates[rule.ruleAddress].isRequired != rule.isRequired) {
            _removeRuleFromStorage(ruleStorage, rule.ruleAddress);
            _addRuleToStorage(ruleStorage, rule.ruleAddress, rule.isRequired);
        }
        (bool success,) = rule.ruleAddress.call(encodedCall);
        require(success, "AddRule: Rule configuration failed");
    }

    function removeRule(RulesStorage storage ruleStorage, address rule) internal {
        require(_ruleAlreadySet(ruleStorage, rule), "RuleNotSet");
        _removeRuleFromStorage(ruleStorage, rule);
    }

    function getRulesArray(RulesStorage storage ruleStorage, bool requiredRules)
        internal
        view
        returns (address[] storage)
    {
        return requiredRules ? ruleStorage.requiredRules : ruleStorage.anyOfRules;
    }
    // Private

    function _addRuleToStorage(RulesStorage storage ruleStorage, address ruleAddress, bool requiredRule) private {
        address[] storage rules = getRulesArray(ruleStorage, requiredRule);
        uint8 index = uint8(rules.length); // TODO: Add a check if needed
        rules.push(ruleAddress);
        ruleStorage.ruleStates[ruleAddress] = RuleState({index: index, isRequired: requiredRule, isSet: true});
    }

    function _removeRuleFromStorage(RulesStorage storage ruleStorage, address ruleAddress) private {
        uint8 index = ruleStorage.ruleStates[ruleAddress].index;
        address[] storage rules = getRulesArray(ruleStorage, ruleStorage.ruleStates[ruleAddress].isRequired);
        if (rules.length > 1) {
            // Copy the last element in the array into the index of the rule to delete
            rules[index] = rules[rules.length - 1];
            // Set the proper index for the swapped rule
            ruleStorage.ruleStates[rules[index]].index = index;
        }
        rules.pop();
        delete ruleStorage.ruleStates[ruleAddress];
    }

    function _ruleAlreadySet(RulesStorage storage ruleStorage, address rule) private view returns (bool) {
        return ruleStorage.ruleStates[rule].isSet;
    }
}
