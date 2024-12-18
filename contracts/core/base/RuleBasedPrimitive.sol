// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {RulesStorage, RulesLib} from "./../libraries/RulesLib.sol";
import {
    RuleChange,
    RuleConfigurationChange,
    RuleSelectorChange,
    RuleProcessingParams,
    Rule,
    KeyValue
} from "./../types/Types.sol";

abstract contract RuleBasedPrimitive {
    using RulesLib for RulesStorage;

    function _changePrimitiveRules(
        RulesStorage storage rulesStorage,
        RuleChange[] calldata ruleChanges
    ) internal virtual {
        _changeRules(
            rulesStorage,
            0,
            ruleChanges,
            new RuleProcessingParams[](0),
            _encodeConfigureCall,
            _emitConfiguredEvent,
            _emitSelectorEvent
        );
    }

    function _changeEntityRules(
        RulesStorage storage rulesStorage,
        uint256 entityId,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] calldata ruleChangesProcessingParams
    ) internal virtual {
        _changeRules(
            rulesStorage,
            entityId,
            ruleChanges,
            ruleChangesProcessingParams,
            _encodeConfigureCall,
            _emitConfiguredEvent,
            _emitSelectorEvent
        );
    }

    function _encodeConfigureCall(
        uint256 entityId,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal pure returns (bytes memory) {
        if (entityId == 0) {
            return _encodePrimitiveConfigureCall(configSalt, ruleParams);
        } else {
            return _encodeEntityConfigureCall(entityId, configSalt, ruleParams);
        }
    }

    function _emitConfiguredEvent(
        bool wasAlreadyConfigured,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal {
        if (entityId == 0) {
            _emitPrimitiveRuleConfiguredEvent(wasAlreadyConfigured, ruleAddress, configSalt, ruleParams);
        } else {
            _emitEntityRuleConfiguredEvent(wasAlreadyConfigured, entityId, ruleAddress, configSalt, ruleParams);
        }
    }

    function _emitSelectorEvent(
        bool enabled,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired,
        bytes4 selector
    ) internal {
        if (entityId == 0) {
            _emitPrimitiveRuleSelectorEvent(enabled, ruleAddress, configSalt, isRequired, selector);
        } else {
            _emitEntityRuleSelectorEvent(enabled, entityId, ruleAddress, configSalt, isRequired, selector);
        }
    }

    // Primitive functions:

    function _encodePrimitiveConfigureCall(
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal pure virtual returns (bytes memory);

    function _emitPrimitiveRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal virtual;

    function _emitPrimitiveRuleSelectorEvent(
        bool enabled,
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired,
        bytes4 selector
    ) internal virtual;

    // Entity functions:

    function _encodeEntityConfigureCall(
        uint256 entityId,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal pure virtual returns (bytes memory) {}

    function _emitEntityRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal virtual {}

    function _emitEntityRuleSelectorEvent(
        bool enabled,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired,
        bytes4 selector
    ) internal virtual {}

    // Internal

    function _changeRules(
        RulesStorage storage rulesStorage,
        uint256 entityId,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] memory ruleChangesProcessingParams,
        function(uint256,bytes32,KeyValue[] calldata) internal returns (bytes memory) fn_encodeConfigureCall,
        function(bool,uint256,address,bytes32,KeyValue[] calldata) internal fn_emitConfiguredEvent,
        function(bool,uint256,address,bytes32,bool,bytes4) internal fn_emitSelectorEvent
    ) private {
        _beforeChangeRules(entityId, ruleChanges);
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleChange memory ruleChange = ruleChanges[i];
            if (ruleChange.configurationChanges.configure) {
                ruleChange.configSalt = _configureRule(
                    rulesStorage,
                    ruleChanges[i].ruleAddress,
                    ruleChanges[i].configSalt,
                    entityId,
                    ruleChanges[i].configurationChanges.ruleParams,
                    fn_encodeConfigureCall,
                    fn_emitConfiguredEvent
                );
            }
            for (uint256 j = 0; j < ruleChange.selectorChanges.length; j++) {
                rulesStorage._changeRulesSelectors(
                    ruleChanges[i].ruleAddress,
                    ruleChange.configSalt,
                    entityId,
                    ruleChanges[i].selectorChanges[j].ruleSelector,
                    ruleChanges[i].selectorChanges[j].isRequired,
                    ruleChanges[i].selectorChanges[j].enabled,
                    fn_emitSelectorEvent
                );
            }
        }
        if (entityId == 0) {
            _validateRulesLength(rulesStorage, _supportedPrimitiveRuleSelectors());
        } else {
            _validateRulesLength(rulesStorage, _supportedEntityRuleSelectors());
            _processEntityRulesChanges(entityId, ruleChanges, ruleChangesProcessingParams); // TODO: Which one we pass? The one with configSalt's already assigned or the original one with the zero-ed configSalt's?
        }
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual returns (bytes4[] memory);

    function _supportedEntityRuleSelectors() internal view virtual returns (bytes4[] memory) {
        return new bytes4[](0);
    }

    function _beforeChangeRules(uint256 entityId, RuleChange[] calldata ruleChanges) internal virtual {
        if (entityId == 0) {
            _beforeChangePrimitiveRules(ruleChanges);
        } else {
            _beforeChangeEntityRules(entityId, ruleChanges);
        }
    }

    function _processEntityRulesChanges(
        uint256 entityId,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] memory ruleChangesProcessingParams
    ) internal virtual {}

    function _validateRulesLength(
        RulesStorage storage rulesStorage,
        bytes4[] memory selectorsToValidate
    ) internal view {
        for (uint256 i = 0; i < selectorsToValidate.length; i++) {
            bytes4 ruleSelector = selectorsToValidate[i];
            uint256 requiredRulesLength = rulesStorage._getRulesArray(ruleSelector, true).length;
            uint256 anyOfRulesLength = rulesStorage._getRulesArray(ruleSelector, false).length;
            require(anyOfRulesLength != 1, "Cannot have exactly one single any-of rule");
            require(requiredRulesLength + anyOfRulesLength <= RulesLib.MAX_AMOUNT_OF_RULES, "Amount of rules exceeded");
        }
    }

    function _beforeChangePrimitiveRules(RuleChange[] calldata ruleChanges) internal virtual {}

    function _beforeChangeEntityRules(uint256 entityId, RuleChange[] calldata ruleChanges) internal virtual {}

    function _configureRule(
        RulesStorage storage rulesStorage,
        address ruleAddress,
        bytes32 providedConfigSalt,
        uint256 entityId,
        KeyValue[] calldata ruleParams,
        function(uint256,bytes32,KeyValue[] calldata) internal returns (bytes memory) fn_encodeConfigureCall,
        function(bool,uint256,address,bytes32,KeyValue[] calldata) internal fn_emitEvent
    ) internal returns (bytes32) {
        bytes32 configSalt = rulesStorage.generateOrValidateConfigSalt(ruleAddress, providedConfigSalt);
        bool wasAlreadyConfigured =
            rulesStorage.configureRule(ruleAddress, configSalt, fn_encodeConfigureCall(entityId, configSalt, ruleParams));
        fn_emitEvent(wasAlreadyConfigured, entityId, ruleAddress, configSalt, ruleParams);
        return configSalt;
    }
}
