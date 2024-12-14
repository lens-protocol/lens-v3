// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {RuleConfigurationParams, Rule} from "./../types/Types.sol";

struct RulesStorage {
    mapping(bytes4 => Rule[]) requiredRules;
    mapping(bytes4 => Rule[]) anyOfRules;
    mapping(bytes4 => mapping(address => mapping(bytes32 => RuleState))) ruleStates;
    uint256 lastConfigSaltGenerated;
}

struct RuleState {
    uint8 index;
    bool isRequired;
    bool isSet;
}

library RulesLib {
    function generateOrValidateConfigSalt(
        RulesStorage storage ruleStorage,
        bytes32 providedConfigSalt
    ) internal returns (bytes32) {
        if (uint256(providedConfigSalt) == 0) {
            return bytes32(++ruleStorage.lastConfigSaltGenerated);
        } else {
            require(uint256(providedConfigSalt) <= ruleStorage.lastConfigSaltGenerated);
            return providedConfigSalt;
        }
    }

    function addRule(
        RulesStorage storage ruleStorage,
        RuleConfigurationParams memory ruleConfig,
        bytes memory encodedConfigureCall
    ) internal {
        require(
            !_ruleAlreadySet(ruleStorage, ruleConfig.ruleSelector, ruleConfig.ruleAddress, ruleConfig.configSalt),
            "AddRule: Same rule was already added"
        );
        _addRuleToStorage(
            ruleStorage, ruleConfig.ruleSelector, ruleConfig.ruleAddress, ruleConfig.configSalt, ruleConfig.isRequired
        );
        (bool success,) = ruleConfig.ruleAddress.call(encodedConfigureCall);
        require(success, "AddRule: Rule configuration failed");
    }

    function updateRule(
        RulesStorage storage ruleStorage,
        RuleConfigurationParams memory ruleConfig,
        bytes memory encodedConfigureCall
    ) internal {
        require(
            _ruleAlreadySet(ruleStorage, ruleConfig.ruleSelector, ruleConfig.ruleAddress, ruleConfig.configSalt),
            "ConfigureRule: Rule doesn't exist"
        );
        if (
            ruleStorage.ruleStates[ruleConfig.ruleSelector][ruleConfig.ruleAddress][ruleConfig.configSalt].isRequired
                != ruleConfig.isRequired
        ) {
            _removeRuleFromStorage(ruleStorage, ruleConfig.ruleSelector, ruleConfig.ruleAddress, ruleConfig.configSalt);
            _addRuleToStorage(
                ruleStorage,
                ruleConfig.ruleSelector,
                ruleConfig.ruleAddress,
                ruleConfig.configSalt,
                ruleConfig.isRequired
            );
        }
        (bool success,) = ruleConfig.ruleAddress.call(encodedConfigureCall);
        require(success, "AddRule: Rule configuration failed");
    }

    function removeRule(RulesStorage storage ruleStorage, RuleConfigurationParams memory ruleConfig) internal {
        require(
            _ruleAlreadySet(ruleStorage, ruleConfig.ruleSelector, ruleConfig.ruleAddress, ruleConfig.configSalt),
            "RuleNotSet"
        );
        _removeRuleFromStorage(ruleStorage, ruleConfig.ruleSelector, ruleConfig.ruleAddress, ruleConfig.configSalt);
    }

    function _getRulesArray(
        RulesStorage storage ruleStorage,
        bytes4 ruleSelector,
        bool requiredRules
    ) internal view returns (Rule[] storage) {
        return requiredRules ? ruleStorage.requiredRules[ruleSelector] : ruleStorage.anyOfRules[ruleSelector];
    }

    // Private

    function _addRuleToStorage(
        RulesStorage storage ruleStorage,
        bytes4 ruleSelector,
        address ruleAddress,
        bytes32 configSalt,
        bool requiredRule
    ) private {
        Rule[] storage rules = _getRulesArray(ruleStorage, ruleSelector, requiredRule);
        uint8 index = uint8(rules.length); // TODO: Add a check if needed
        rules.push(Rule(ruleAddress, configSalt));
        ruleStorage.ruleStates[ruleSelector][ruleAddress][configSalt] =
            RuleState({index: index, isRequired: requiredRule, isSet: true});
    }

    function _removeRuleFromStorage(
        RulesStorage storage ruleStorage,
        bytes4 ruleSelector,
        address ruleAddress,
        bytes32 configSalt
    ) private {
        uint8 index = ruleStorage.ruleStates[ruleSelector][ruleAddress][configSalt].index;
        Rule[] storage rules = _getRulesArray(
            ruleStorage, ruleSelector, ruleStorage.ruleStates[ruleSelector][ruleAddress][configSalt].isRequired
        );
        if (rules.length > 1) {
            // Copy the last element in the array into the index of the rule to delete
            rules[index] = rules[rules.length - 1];
            // Set the proper index for the swapped rule
            ruleStorage.ruleStates[ruleSelector][rules[index].addr][rules[index].configSalt].index = index;
        }
        rules.pop();
        delete ruleStorage.ruleStates[ruleSelector][ruleAddress][configSalt];
    }

    function _ruleAlreadySet(
        RulesStorage storage ruleStorage,
        bytes4 ruleSelector,
        address rule,
        bytes32 configSalt
    ) private view returns (bool) {
        return ruleStorage.ruleStates[ruleSelector][rule][configSalt].isSet;
    }
}
