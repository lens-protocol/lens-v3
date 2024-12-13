// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IUsernameRule} from "./../../interfaces/IUsernameRule.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {
    Rule,
    RuleChange,
    RuleOperation,
    RuleProcessingParams,
    RuleConfigurationParams,
    KeyValue
} from "./../../types/Types.sol";
import {IUsername} from "./../../interfaces/IUsername.sol";

abstract contract RuleBasedUsername is IUsername {
    using RulesLib for RulesStorage;

    struct RuleBasedStorage {
        RulesStorage usernameRulesStorage;
    }

    // keccak256('lens.rule.based.username.storage')
    bytes32 constant RULE_BASED_USERNAME_STORAGE_SLOT =
        0xdb7398dc7b1d4544bdce6830d22802260c007b71c45e9fa93889a6ec0667be87;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := RULE_BASED_USERNAME_STORAGE_SLOT
        }
    }

    function $usernameRulesStorage() private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().usernameRulesStorage;
    }

    // Public

    function changeUsernameRules(RuleChange[] calldata ruleChanges) external virtual override {
        _beforeChangeUsernameRules(ruleChanges);
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleConfigurationParams memory ruleConfig = ruleChanges[i].configuration;
            if (ruleChanges[i].operation == RuleOperation.ADD) {
                _addUsernameRule(ruleConfig);
                emit IUsername.Lens_Username_RuleAdded(
                    ruleConfig.ruleAddress,
                    ruleConfig.configSalt,
                    ruleConfig.ruleSelector,
                    ruleConfig.customParams,
                    ruleConfig.isRequired
                );
            } else if (ruleChanges[i].operation == RuleOperation.UPDATE) {
                _updateUsernameRule(ruleConfig);
                emit IUsername.Lens_Username_RuleUpdated(
                    ruleConfig.ruleAddress,
                    ruleConfig.configSalt,
                    ruleConfig.ruleSelector,
                    ruleConfig.customParams,
                    ruleConfig.isRequired
                );
            } else {
                _removeUsernameRule(ruleConfig);
                emit IUsername.Lens_Username_RuleRemoved(
                    ruleConfig.ruleAddress, ruleConfig.configSalt, ruleConfig.ruleSelector
                );
            }
        }
        require(
            $usernameRulesStorage().anyOfRules[IUsernameRule.processCreation.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $usernameRulesStorage().anyOfRules[IUsernameRule.processAssigning.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
    }

    function getUsernameRules(
        bytes4 ruleSelector,
        bool isRequired
    ) external view virtual override returns (Rule[] memory) {
        return $usernameRulesStorage()._getRulesArray(ruleSelector, isRequired);
    }

    // Internal

    function _beforeChangeUsernameRules(RuleChange[] calldata ruleChanges) internal virtual {}

    function _addUsernameRule(RuleConfigurationParams memory rule) internal {
        $usernameRulesStorage().addRule(
            rule, abi.encodeCall(IUsernameRule.configure, (rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _updateUsernameRule(RuleConfigurationParams memory rule) internal {
        $usernameRulesStorage().updateRule(
            rule, abi.encodeCall(IUsernameRule.configure, (rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _removeUsernameRule(RuleConfigurationParams memory rule) internal {
        $usernameRulesStorage().removeRule(rule);
    }

    function _encodeAndCallProcessCreation(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string memory username,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IUsernameRule.processCreation,
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
        _processUsernameRule(
            _encodeAndCallProcessCreation,
            IUsernameRule.processCreation.selector,
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
        return rule.call(
            abi.encodeCall(
                IUsernameRule.processRemoval,
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
        _processUsernameRule(
            _encodeAndCallProcessRemoval,
            IUsernameRule.processRemoval.selector,
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
        return rule.call(
            abi.encodeCall(
                IUsernameRule.processAssigning,
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
        _processUsernameRule(
            _encodeAndCallProcessAssigning,
            IUsernameRule.processAssigning.selector,
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
        return rule.call(
            abi.encodeCall(
                IUsernameRule.processUnassigning,
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
        _processUsernameRule(
            _encodeAndCallProcessUnassigning,
            IUsernameRule.processUnassigning.selector,
            originalMsgSender,
            account,
            username,
            primitiveCustomParams,
            rulesProcessingParams
        );
    }

    function _processUsernameRule(
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
        for (uint256 i = 0; i < $usernameRulesStorage().requiredRules[ruleSelector].length; i++) {
            Rule memory rule = $usernameRulesStorage().requiredRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr,
                    rule.configSalt,
                    originalMsgSender,
                    account,
                    username,
                    primitiveCustomParams,
                    ruleCustomParams
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $usernameRulesStorage().anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = $usernameRulesStorage().anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr,
                    rule.configSalt,
                    originalMsgSender,
                    account,
                    username,
                    primitiveCustomParams,
                    ruleCustomParams
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($usernameRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }
}
