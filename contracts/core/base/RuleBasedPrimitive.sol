// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {RulesStorage, RulesLib} from "contracts/core/libraries/RulesLib.sol";
import {
    RuleChange,
    RuleConfigurationChange,
    RuleSelectorChange,
    RuleProcessingParams,
    Rule,
    KeyValue
} from "contracts/core/types/Types.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";
import {Errors} from "contracts/core/types/Errors.sol";

abstract contract RuleBasedPrimitive {
    using RulesLib for RulesStorage;
    using CallLib for address;

    function _changePrimitiveRules(RulesStorage storage rulesStorage, RuleChange[] memory ruleChanges)
        internal
        virtual
    {
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
        RuleChange[] memory ruleChanges,
        RuleProcessingParams[] memory ruleChangesProcessingParams
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

    function _encodeConfigureCall(uint256 entityId, bytes32 configSalt, KeyValue[] memory ruleParams)
        internal
        pure
        returns (bytes memory)
    {
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
        KeyValue[] memory ruleParams
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

    function _encodePrimitiveConfigureCall(bytes32 configSalt, KeyValue[] memory ruleParams)
        internal
        pure
        virtual
        returns (bytes memory);

    function _emitPrimitiveRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] memory ruleParams
    ) internal virtual;

    function _emitPrimitiveRuleSelectorEvent(
        bool enabled,
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired,
        bytes4 selector
    ) internal virtual;

    // Entity functions:

    function _encodeEntityConfigureCall(uint256 entityId, bytes32 configSalt, KeyValue[] memory ruleParams)
        internal
        pure
        virtual
        returns (bytes memory);

    function _emitEntityRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] memory ruleParams
    ) internal virtual;

    function _emitEntityRuleSelectorEvent(
        bool enabled,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired,
        bytes4 selector
    ) internal virtual;

    // Internal

    function _changeRules(
        RulesStorage storage rulesStorage,
        uint256 entityId,
        RuleChange[] memory ruleChanges,
        RuleProcessingParams[] memory ruleChangesProcessingParams,
        function(uint256,bytes32,KeyValue[] memory) internal returns (bytes memory) fn_encodeConfigureCall,
        function(bool,uint256,address,bytes32,KeyValue[] memory) internal fn_emitConfiguredEvent,
        function(bool,uint256,address,bytes32,bool,bytes4) internal fn_emitSelectorEvent
    ) private {
        _beforeChangeRules(entityId, ruleChanges);
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleChange memory ruleChange = ruleChanges[i];
            if (ruleChange.configurationChanges.configure) {
                ruleChange.configSalt =
                    _configureRule(rulesStorage, ruleChange, entityId, fn_encodeConfigureCall, fn_emitConfiguredEvent);
            }
            for (uint256 j = 0; j < ruleChange.selectorChanges.length; j++) {
                _validateIsSupportedRuleSelector(
                    ruleChange.selectorChanges[j].ruleSelector,
                    entityId == 0 ? _supportedPrimitiveRuleSelectors() : _supportedEntityRuleSelectors()
                );
                rulesStorage._changeRulesSelectors(
                    ruleChange, entityId, ruleChange.selectorChanges[j], fn_emitSelectorEvent
                );
            }
        }
        if (entityId == 0) {
            _validateRulesLength(rulesStorage, _supportedPrimitiveRuleSelectors());
        } else {
            _validateRulesLength(rulesStorage, _supportedEntityRuleSelectors());
            _processEntityRulesChanges(entityId, ruleChanges, ruleChangesProcessingParams);
        }
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual returns (bytes4[] memory);

    function _supportedEntityRuleSelectors() internal view virtual returns (bytes4[] memory) {
        return new bytes4[](0);
    }

    function _validateIsSupportedRuleSelector(bytes4 ruleSelectorToValidate, bytes4[] memory supportedRuleSelectors)
        internal
        pure
    {
        for (uint256 i = 0; i < supportedRuleSelectors.length; i++) {
            if (ruleSelectorToValidate == supportedRuleSelectors[i]) {
                return;
            }
        }
        revert Errors.UnsupportedSelector();
    }

    function _beforeChangeRules(uint256 entityId, RuleChange[] memory ruleChanges) internal virtual {
        if (entityId == 0) {
            _beforeChangePrimitiveRules(ruleChanges);
        } else {
            _beforeChangeEntityRules(entityId, ruleChanges);
        }
    }

    function _processEntityRulesChanges(
        uint256 entityId,
        RuleChange[] memory ruleChanges,
        RuleProcessingParams[] memory ruleChangesProcessingParams
    ) internal virtual {}

    function _validateRulesLength(RulesStorage storage rulesStorage, bytes4[] memory selectorsToValidate)
        internal
        view
    {
        for (uint256 i = 0; i < selectorsToValidate.length; i++) {
            bytes4 ruleSelector = selectorsToValidate[i];
            uint256 requiredRulesLength = rulesStorage._getRulesArray(ruleSelector, true).length;
            uint256 anyOfRulesLength = rulesStorage._getRulesArray(ruleSelector, false).length;
            // Having a single any-of rule makes it behave like a required rule. We permit it, but you can uncomment
            // the following check if it is important for you to disallow it.
            // require(anyOfRulesLength != 1, Errors.SingleAnyOfRule());
            require(requiredRulesLength + anyOfRulesLength <= RulesLib.MAX_AMOUNT_OF_RULES, Errors.LimitReached());
        }
    }

    function _beforeChangePrimitiveRules(RuleChange[] memory ruleChanges) internal virtual;

    function _beforeChangeEntityRules(uint256 entityId, RuleChange[] memory ruleChanges) internal virtual;

    function _configureRule(
        RulesStorage storage rulesStorage,
        RuleChange memory ruleChange,
        uint256 entityId,
        function(uint256,bytes32,KeyValue[] memory) internal returns (bytes memory) fn_encodeConfigureCall,
        function(bool,uint256,address,bytes32,KeyValue[] memory) internal fn_emitEvent
    ) internal returns (bytes32) {
        bytes32 configSalt = rulesStorage.generateOrValidateConfigSalt(ruleChange.ruleAddress, ruleChange.configSalt);
        bool wasAlreadyConfigured = rulesStorage.configureRule(
            ruleChange.ruleAddress,
            configSalt,
            fn_encodeConfigureCall(entityId, configSalt, ruleChange.configurationChanges.ruleParams)
        );
        fn_emitEvent(
            wasAlreadyConfigured,
            entityId,
            ruleChange.ruleAddress,
            configSalt,
            ruleChange.configurationChanges.ruleParams
        );
        return configSalt;
    }

    function _getRuleParamsOrEmptyArray(Rule memory rule, RuleProcessingParams[] memory rulesProcessingParams)
        internal
        pure
        returns (KeyValue[] memory)
    {
        for (uint256 i = 0; i < rulesProcessingParams.length; i++) {
            if (
                rulesProcessingParams[i].ruleAddress == rule.ruleAddress
                    && rulesProcessingParams[i].configSalt == rule.configSalt
            ) {
                return rulesProcessingParams[i].ruleParams;
            }
        }
        return new KeyValue[](0);
    }
}
