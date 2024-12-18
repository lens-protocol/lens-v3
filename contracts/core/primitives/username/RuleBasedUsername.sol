// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IUsernameRule} from "./../../interfaces/IUsernameRule.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {RuleChange, RuleProcessingParams, Rule, KeyValue} from "./../../types/Types.sol";
import {IUsername} from "./../../interfaces/IUsername.sol";
import {RuleBasedPrimitive} from "./../../base/RuleBasedPrimitive.sol";

abstract contract RuleBasedUsername is IUsername, RuleBasedPrimitive {
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

    ////////////////////////////  CONFIGURATION FUNCTIONS  ////////////////////////////

    function changeUsernameRules(RuleChange[] calldata ruleChanges) external virtual override {
        _changePrimitiveRules($usernameRulesStorage(), ruleChanges);
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IUsernameRule.processCreation.selector;
        selectors[1] = IUsernameRule.processRemoval.selector;
        selectors[2] = IUsernameRule.processAssigning.selector;
        selectors[3] = IUsernameRule.processUnassigning.selector;
        return selectors;
    }

    function _encodePrimitiveConfigureCall(
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal pure override returns (bytes memory) {
        return abi.encodeCall(IUsernameRule.configure, (configSalt, ruleParams));
    }

    function _emitPrimitiveRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal override {
        if (wasAlreadyConfigured) {
            emit IUsername.Lens_Username_RuleReconfigured(ruleAddress, configSalt, ruleParams);
        } else {
            emit IUsername.Lens_Username_RuleConfigured(ruleAddress, configSalt, ruleParams);
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
            emit Lens_Username_RuleSelectorEnabled(ruleAddress, configSalt, isRequired, ruleSelector);
        } else {
            emit Lens_Username_RuleSelectorDisabled(ruleAddress, configSalt, isRequired, ruleSelector);
        }
    }

    function _amountOfRules(bytes4 ruleSelector) internal view returns (uint256) {
        return $usernameRulesStorage()._getRulesArray(ruleSelector, false).length
            + $usernameRulesStorage()._getRulesArray(ruleSelector, true).length;
    }

    function getUsernameRules(
        bytes4 ruleSelector,
        bool isRequired
    ) external view virtual override returns (Rule[] memory) {
        return $usernameRulesStorage()._getRulesArray(ruleSelector, isRequired);
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
                KeyValue[] memory ruleParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.ruleAddress,
                    rule.configSalt,
                    originalMsgSender,
                    account,
                    username,
                    primitiveCustomParams,
                    ruleParams
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $usernameRulesStorage().anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = $usernameRulesStorage().anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.ruleAddress,
                    rule.configSalt,
                    originalMsgSender,
                    account,
                    username,
                    primitiveCustomParams,
                    ruleParams
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
