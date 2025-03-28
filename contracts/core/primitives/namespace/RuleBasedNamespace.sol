// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";
import {RulesStorage, RulesLib} from "contracts/core/libraries/RulesLib.sol";
import {RuleChange, RuleProcessingParams, Rule, KeyValue} from "contracts/core/types/Types.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";
import {RuleBasedPrimitive} from "contracts/core/base/RuleBasedPrimitive.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";
import {Errors} from "contracts/core/types/Errors.sol";

abstract contract RuleBasedNamespace is INamespace, RuleBasedPrimitive {
    using RulesLib for RulesStorage;
    using CallLib for address;

    struct RuleBasedStorage {
        RulesStorage namespaceRulesStorage;
    }

    /// @custom:keccak lens.storage.RuleBasedNamespace
    bytes32 constant STORAGE__RULE_BASED_NAMESPACE = 0x2b39616f97e9eef16558dd56193aaab38d2eb87d6444b98781a13eea228ddaae;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__RULE_BASED_NAMESPACE
        }
    }

    function $namespaceRulesStorage() private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().namespaceRulesStorage;
    }

    ////////////////////////////  CONFIGURATION FUNCTIONS  ////////////////////////////

    function changeNamespaceRules(RuleChange[] calldata ruleChanges) external virtual override {
        _changePrimitiveRules($namespaceRulesStorage(), ruleChanges);
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = INamespaceRule.processCreation.selector;
        selectors[1] = INamespaceRule.processRemoval.selector;
        selectors[2] = INamespaceRule.processAssigning.selector;
        selectors[3] = INamespaceRule.processUnassigning.selector;
        return selectors;
    }

    function _encodePrimitiveConfigureCall(bytes32 configSalt, KeyValue[] memory ruleParams)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encodeCall(INamespaceRule.configure, (configSalt, ruleParams));
    }

    function _encodeEntityConfigureCall(uint256 entityId, bytes32 configSalt, KeyValue[] memory ruleParams)
        internal
        pure
        override
        returns (bytes memory)
    {}

    function _emitPrimitiveRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] memory ruleParams
    ) internal override {
        if (wasAlreadyConfigured) {
            emit INamespace.Lens_Namespace_RuleReconfigured(ruleAddress, configSalt, ruleParams);
        } else {
            emit INamespace.Lens_Namespace_RuleConfigured(ruleAddress, configSalt, ruleParams);
        }
    }

    function _emitPrimitiveRuleSelectorEvent(
        bool enabled,
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired,
        bytes4 ruleSelector
    ) internal override {
        if (enabled) {
            emit Lens_Namespace_RuleSelectorEnabled(ruleAddress, configSalt, isRequired, ruleSelector);
        } else {
            emit Lens_Namespace_RuleSelectorDisabled(ruleAddress, configSalt, isRequired, ruleSelector);
        }
    }

    function _emitEntityRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] memory ruleParams
    ) internal override {}

    function _emitEntityRuleSelectorEvent(
        bool enabled,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired,
        bytes4 selector
    ) internal override {}

    function getNamespaceRules(bytes4 ruleSelector, bool isRequired)
        external
        view
        virtual
        override
        returns (Rule[] memory)
    {
        return $namespaceRulesStorage()._getRulesArray(ruleSelector, isRequired);
    }

    ////////////////////////////  PROCESSING FUNCTIONS  ////////////////////////////

    function _encodeAndCallProcessCreation(
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                INamespaceRule.processCreation,
                (
                    rule.configSalt,
                    processParams.originalMsgSender,
                    processParams.account,
                    processParams.username,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _processCreation(
        address originalMsgSender,
        address account,
        string memory username,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        _processNamespaceRule(
            _encodeAndCallProcessCreation,
            ProcessParams({
                ruleSelector: INamespaceRule.processCreation.selector,
                originalMsgSender: originalMsgSender,
                account: account,
                username: username,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: rulesProcessingParams
            })
        );
    }

    function _encodeAndCallProcessRemoval(
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                INamespaceRule.processRemoval,
                (
                    rule.configSalt,
                    processParams.originalMsgSender,
                    processParams.username,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _processRemoval(
        address originalMsgSender,
        string memory username,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        _processNamespaceRule(
            _encodeAndCallProcessRemoval,
            ProcessParams({
                ruleSelector: INamespaceRule.processRemoval.selector,
                originalMsgSender: originalMsgSender,
                account: address(0),
                username: username,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: rulesProcessingParams
            })
        );
    }

    function _encodeAndCallProcessAssigning(
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                INamespaceRule.processAssigning,
                (
                    rule.configSalt,
                    processParams.originalMsgSender,
                    processParams.account,
                    processParams.username,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _processAssigning(
        address originalMsgSender,
        address account,
        string memory username,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        _processNamespaceRule(
            _encodeAndCallProcessAssigning,
            ProcessParams({
                ruleSelector: INamespaceRule.processAssigning.selector,
                originalMsgSender: originalMsgSender,
                account: account,
                username: username,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: rulesProcessingParams
            })
        );
    }

    function _encodeAndCallProcessUnassigning(
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                INamespaceRule.processUnassigning,
                (
                    rule.configSalt,
                    processParams.originalMsgSender,
                    processParams.account,
                    processParams.username,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _processUnassigning(
        address originalMsgSender,
        address account,
        string memory username,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        _processNamespaceRule(
            _encodeAndCallProcessUnassigning,
            ProcessParams({
                ruleSelector: INamespaceRule.processUnassigning.selector,
                originalMsgSender: originalMsgSender,
                account: account,
                username: username,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: rulesProcessingParams
            })
        );
    }

    struct ProcessParams {
        bytes4 ruleSelector;
        address originalMsgSender;
        address account;
        string username;
        KeyValue[] primitiveCustomParams;
        RuleProcessingParams[] rulesProcessingParams;
    }

    function _processNamespaceRule(
        function(Rule memory,ProcessParams memory,KeyValue[] memory) internal returns (bool,bytes memory) encodeAndCall,
        ProcessParams memory processParams
    ) private {
        Rule memory rule;
        KeyValue[] memory ruleParams;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $namespaceRulesStorage().requiredRules[processParams.ruleSelector].length; i++) {
            rule = $namespaceRulesStorage().requiredRules[processParams.ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            require(callSucceeded, Errors.RequiredRuleReverted());
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $namespaceRulesStorage().anyOfRules[processParams.ruleSelector].length; i++) {
            rule = $namespaceRulesStorage().anyOfRules[processParams.ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            if (callSucceeded) {
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require(
            $namespaceRulesStorage().anyOfRules[processParams.ruleSelector].length == 0, Errors.AllAnyOfRulesReverted()
        );
    }
}
