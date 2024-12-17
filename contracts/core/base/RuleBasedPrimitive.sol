// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {RulesStorage, RulesLib} from "./../libraries/RulesLib.sol";
import {RuleConfigurationChange, RuleSelectorChange, RuleProcessingParams, Rule, KeyValue} from "./../types/Types.sol";

abstract contract RuleBasedPrimitive {
    using RulesLib for RulesStorage;

    function _changePrimitiveRules(
        RulesStorage storage rulesStorage,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        function(uint256,bytes32,KeyValue[] calldata) internal returns (bytes memory) fn_encodeConfigureCall,
        function(bool,uint256,address,bytes32,KeyValue[] calldata) internal fn_emitConfiguredEvent,
        function(bool,uint256,address,bytes32,bool,bytes4) internal fn_emitSelectorEvent
    ) internal virtual {
        _changeRules(
            rulesStorage,
            0,
            configChanges,
            selectorChanges,
            new RuleProcessingParams[](0),
            fn_encodeConfigureCall,
            fn_emitConfiguredEvent,
            fn_emitSelectorEvent
        );
    }

    function _changeEntityRules(
        RulesStorage storage rulesStorage,
        uint256 entityId,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        RuleProcessingParams[] calldata ruleChangesProcessingParams,
        function(uint256,bytes32,KeyValue[] calldata) internal returns (bytes memory) fn_encodeConfigureCall,
        function(bool,uint256,address,bytes32,KeyValue[] calldata) internal fn_emitConfiguredEvent,
        function(bool,uint256,address,bytes32,bool,bytes4) internal fn_emitSelectorEvent
    ) internal virtual {
        _changeRules(
            rulesStorage,
            entityId,
            configChanges,
            selectorChanges,
            ruleChangesProcessingParams,
            fn_encodeConfigureCall,
            fn_emitConfiguredEvent,
            fn_emitSelectorEvent
        );
    }

    function _changeRules(
        RulesStorage storage rulesStorage,
        uint256 entityId,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        RuleProcessingParams[] memory ruleChangesProcessingParams,
        function(uint256,bytes32,KeyValue[] calldata) internal returns (bytes memory) fn_encodeConfigureCall,
        function(bool,uint256,address,bytes32,KeyValue[] calldata) internal fn_emitConfiguredEvent,
        function(bool,uint256,address,bytes32,bool,bytes4) internal fn_emitSelectorEvent
    ) private {
        if (entityId == 0) {
            _beforeChangePrimitiveRules(configChanges, selectorChanges);
        } else {
            _beforeChangeEntityRules(entityId, configChanges, selectorChanges);
        }
        for (uint256 i = 0; i < configChanges.length; i++) {
            _configureRule(rulesStorage, entityId, configChanges[i], fn_encodeConfigureCall, fn_emitConfiguredEvent);
        }
        for (uint256 i = 0; i < selectorChanges.length; i++) {
            rulesStorage._changeRulesSelectors(entityId, selectorChanges[i], fn_emitSelectorEvent);
        }
        if (entityId == 0) {
            _validateRulesLength(rulesStorage, _supportedPrimitiveRuleSelectors());
        } else {
            _validateRulesLength(rulesStorage, _supportedEntityRuleSelectors());
            _processEntityRulesChanges(entityId, configChanges, selectorChanges, ruleChangesProcessingParams);
        }
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual returns (bytes4[] memory);

    function _supportedEntityRuleSelectors() internal view virtual returns (bytes4[] memory) {
        return new bytes4[](0);
    }

    function _processEntityRulesChanges(
        uint256 entityId,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
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

    function _beforeChangePrimitiveRules(
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges
    ) internal virtual {}

    function _beforeChangeEntityRules(
        uint256 entityId,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges
    ) internal virtual {}

    function _configureRule(
        RulesStorage storage rulesStorage,
        uint256 entityId,
        RuleConfigurationChange calldata ruleConfigChange,
        function(uint256,bytes32,KeyValue[] calldata) internal returns (bytes memory) fn_encodeConfigureCall,
        function(bool,uint256,address,bytes32,KeyValue[] calldata) internal fn_emitEvent
    ) internal {
        Rule memory rule;
        rule.addr = ruleConfigChange.ruleAddress;
        rule.configSalt =
            rulesStorage.generateOrValidateConfigSalt(ruleConfigChange.ruleAddress, ruleConfigChange.configSalt);
        bool wasAlreadyConfigured = rulesStorage.configureRule(
            rule, fn_encodeConfigureCall(entityId, rule.configSalt, ruleConfigChange.ruleParams)
        );
        fn_emitEvent(wasAlreadyConfigured, entityId, rule.addr, rule.configSalt, ruleConfigChange.ruleParams);
    }
}
