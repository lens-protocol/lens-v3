// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {Rule} from "./../types/Types.sol";

struct RulesStorage {
    mapping(bytes4 => Rule[]) requiredRules;
    mapping(bytes4 => Rule[]) anyOfRules;
    mapping(bytes4 => mapping(address => mapping(bytes32 => RuleState))) ruleStates;
    mapping(address => mapping(bytes32 => bool)) isConfigured;
    uint256 lastConfigSaltGenerated;
}

struct RuleState {
    uint8 index;
    bool isRequired;
    bool isEnabled;
}

library RulesLib {
    uint256 constant MAX_AMOUNT_OF_RULES = 20;

    function generateOrValidateConfigSalt(
        RulesStorage storage rulesStorage,
        address ruleAddress,
        bytes32 providedConfigSalt
    ) internal returns (bytes32) {
        if (providedConfigSalt == 0x00) {
            return bytes32(++rulesStorage.lastConfigSaltGenerated); // TODO: We can choose another generation procedure
        } else {
            require(rulesStorage.isConfigured[ruleAddress][providedConfigSalt]);
            return providedConfigSalt;
        }
    }

    function configureRule(
        RulesStorage storage rulesStorage,
        address ruleAddress,
        bytes32 configSalt,
        bytes memory encodedConfigureCall
    ) internal returns (bool) {
        bool wasAlreadyConfigured = rulesStorage.isConfigured[ruleAddress][configSalt];
        rulesStorage.isConfigured[ruleAddress][configSalt] = true;
        (bool success,) = ruleAddress.call(encodedConfigureCall);
        require(success);
        return wasAlreadyConfigured;
    }

    function enableRuleSelector(
        RulesStorage storage rulesStorage,
        bool isRequired,
        address ruleAddress,
        bytes32 configSalt,
        bytes4 ruleSelector
    ) internal {
        require(rulesStorage.isConfigured[ruleAddress][configSalt]);
        require(!_isSelectorAlreadyEnabled(rulesStorage, ruleSelector, ruleAddress, configSalt));
        _addRuleSelectorToStorage(rulesStorage, ruleSelector, ruleAddress, configSalt, isRequired);
    }

    function disableRuleSelector(
        RulesStorage storage rulesStorage,
        bool, /* isRequired */
        address ruleAddress,
        bytes32 configSalt,
        bytes4 ruleSelector
    ) internal {
        require(_isSelectorAlreadyEnabled(rulesStorage, ruleSelector, ruleAddress, configSalt));
        _removeRuleSelectorFromStorage(rulesStorage, ruleSelector, ruleAddress, configSalt);
    }

    function _getRulesArray(
        RulesStorage storage rulesStorage,
        bytes4 ruleSelector,
        bool requiredRules
    ) internal view returns (Rule[] storage) {
        return requiredRules ? rulesStorage.requiredRules[ruleSelector] : rulesStorage.anyOfRules[ruleSelector];
    }

    function _changeRulesSelectors(
        RulesStorage storage rulesStorage,
        address ruleAddress,
        bytes32 configSalt,
        uint256 entityId,
        bytes4 ruleSelector,
        bool isRequired,
        bool enabled,
        function(bool,uint256,address,bytes32,bool,bytes4) internal fn_emitEvent
    ) internal {
        function(RulesStorage storage, bool, address, bytes32, bytes4) internal fn_changeRuleSelector =
            enabled ? RulesLib.enableRuleSelector : RulesLib.disableRuleSelector;
        fn_changeRuleSelector(rulesStorage, isRequired, ruleAddress, configSalt, ruleSelector);
        fn_emitEvent(enabled, entityId, ruleAddress, configSalt, isRequired, ruleSelector);
    }

    // Private

    function _addRuleSelectorToStorage(
        RulesStorage storage rulesStorage,
        bytes4 ruleSelector,
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired
    ) private {
        Rule[] storage rules = _getRulesArray(rulesStorage, ruleSelector, isRequired);
        uint8 index = uint8(rules.length);
        rules.push(Rule(ruleAddress, configSalt));
        rulesStorage.ruleStates[ruleSelector][ruleAddress][configSalt] =
            RuleState({index: index, isRequired: isRequired, isEnabled: true});
    }

    function _removeRuleSelectorFromStorage(
        RulesStorage storage rulesStorage,
        bytes4 ruleSelector,
        address ruleAddress,
        bytes32 configSalt
    ) private {
        uint8 index = rulesStorage.ruleStates[ruleSelector][ruleAddress][configSalt].index;
        Rule[] storage rules = _getRulesArray(
            rulesStorage, ruleSelector, rulesStorage.ruleStates[ruleSelector][ruleAddress][configSalt].isRequired
        );
        if (rules.length > 1) {
            // Copy the last element in the array into the index of the rule to delete
            rules[index] = rules[rules.length - 1];
            // Set the proper index for the swapped rule
            rulesStorage.ruleStates[ruleSelector][rules[index].ruleAddress][rules[index].configSalt].index = index;
        }
        rules.pop();
        delete rulesStorage.ruleStates[ruleSelector][ruleAddress][configSalt];
    }

    function _isSelectorAlreadyEnabled(
        RulesStorage storage rulesStorage,
        bytes4 ruleSelector,
        address ruleAddress,
        bytes32 configSalt
    ) private view returns (bool) {
        return rulesStorage.ruleStates[ruleSelector][ruleAddress][configSalt].isEnabled;
    }
}
