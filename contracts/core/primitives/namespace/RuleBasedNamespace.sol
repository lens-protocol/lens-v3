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

    function _encodePrimitiveConfigureCall(bytes32 configSalt, KeyValue[] calldata ruleParams)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encodeCall(INamespaceRule.configure, (configSalt, ruleParams));
    }

    function _emitPrimitiveRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
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

    function _amountOfRules(bytes4 ruleSelector) internal view returns (uint256) {
        return $namespaceRulesStorage()._getRulesArray(ruleSelector, false).length
            + $namespaceRulesStorage()._getRulesArray(ruleSelector, true).length;
    }

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
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string memory username,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.safecall(
            abi.encodeCall(
                INamespaceRule.processCreation,
                (configSalt, originalMsgSender, account, username, primitiveCustomParams, ruleCustomParams)
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
            INamespaceRule.processCreation.selector,
            originalMsgSender,
            account,
            username,
            primitiveCustomParams,
            rulesProcessingParams
        );
    }

    function _encodeAndCallProcessRemoval(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string memory username,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.safecall(
            abi.encodeCall(
                INamespaceRule.processRemoval,
                (configSalt, originalMsgSender, username, primitiveCustomParams, ruleCustomParams)
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
            INamespaceRule.processRemoval.selector,
            originalMsgSender,
            address(0),
            username,
            primitiveCustomParams,
            rulesProcessingParams
        );
    }

    function _encodeAndCallProcessAssigning(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string memory username,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.safecall(
            abi.encodeCall(
                INamespaceRule.processAssigning,
                (configSalt, originalMsgSender, account, username, primitiveCustomParams, ruleCustomParams)
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
            INamespaceRule.processAssigning.selector,
            originalMsgSender,
            account,
            username,
            primitiveCustomParams,
            rulesProcessingParams
        );
    }

    function _encodeAndCallProcessUnassigning(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string memory username,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.safecall(
            abi.encodeCall(
                INamespaceRule.processUnassigning,
                (configSalt, originalMsgSender, account, username, primitiveCustomParams, ruleCustomParams)
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
            INamespaceRule.processUnassigning.selector,
            originalMsgSender,
            account,
            username,
            primitiveCustomParams,
            rulesProcessingParams
        );
    }

    function _processNamespaceRule(
        function(address,bytes32,address,address,string memory,KeyValue[] calldata,KeyValue[] memory) internal returns (bool,bytes memory)
            encodeAndCall,
        bytes4 ruleSelector,
        address originalMsgSender,
        address account,
        string memory username,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) private {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $namespaceRulesStorage().requiredRules[ruleSelector].length; i++) {
            Rule memory rule = $namespaceRulesStorage().requiredRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleParams = rulesProcessingParams[j].ruleParams;
                }
                // (bool callNotReverted,) = encodeAndCall(
                //     rule.ruleAddress,
                //     rule.configSalt,
                //     originalMsgSender,
                //     account,
                //     username,
                //     primitiveCustomParams,
                //     ruleParams
                // );
                // require(callNotReverted, Errors.RequiredRuleReverted());
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $namespaceRulesStorage().anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = $namespaceRulesStorage().anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleParams = rulesProcessingParams[j].ruleParams;
                }
                // (bool callNotReverted,) = encodeAndCall(
                //     rule.ruleAddress,
                //     rule.configSalt,
                //     originalMsgSender,
                //     account,
                //     username,
                //     primitiveCustomParams,
                //     ruleParams
                // );
                // if (callNotReverted) {
                //     return; // If any of the OR-combined rules passed, it means they succeed and we can return
                // }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($namespaceRulesStorage().anyOfRules[ruleSelector].length == 0, Errors.AllAnyOfRulesReverted());
    }
}
