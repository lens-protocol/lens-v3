// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroupRule} from "./../../interfaces/IGroupRule.sol";
import {IGroup} from "./../../interfaces/IGroup.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {
    RuleConfigurationChange, RuleSelectorChange, RuleProcessingParams, Rule, KeyValue
} from "./../../types/Types.sol";
import {RuleBasedPrimitive} from "./../../base/RuleBasedPrimitive.sol";

abstract contract RuleBasedGroup is IGroup, RuleBasedPrimitive {
    using RulesLib for RulesStorage;

    struct RuleBasedStorage {
        RulesStorage groupRulesStorage;
    }

    // keccak256('lens.rule.based.group.storage')
    bytes32 constant RULE_BASED_GROUP_STORAGE_SLOT = 0x6b4f86fd68b78c2e5c3c4bc3b3dbb99669a3da3f0bb2db367c4d64acdb2fd3d9;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := RULE_BASED_GROUP_STORAGE_SLOT
        }
    }

    function $groupRulesStorage() private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().groupRulesStorage;
    }

    ////////////////////////////  CONFIGURATION FUNCTIONS  ////////////////////////////

    function changeGroupRules(
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges
    ) external virtual override {
        _changePrimitiveRules(
            $groupRulesStorage(),
            configChanges,
            selectorChanges,
            _encodeConfigureCall,
            _emitGroupRuleConfiguredEvent,
            _emitGroupRuleSelectorEvent
        );
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IGroupRule.processAddition.selector;
        selectors[1] = IGroupRule.processRemoval.selector;
        selectors[2] = IGroupRule.processJoining.selector;
        selectors[3] = IGroupRule.processLeaving.selector;
        return selectors;
    }

    function _amountOfRules(bytes4 ruleSelector) internal view returns (uint256) {
        return $groupRulesStorage()._getRulesArray(ruleSelector, false).length
            + $groupRulesStorage()._getRulesArray(ruleSelector, true).length;
    }

    function getGroupRules(
        bytes4 ruleSelector,
        bool isRequired
    ) external view virtual override returns (Rule[] memory) {
        return $groupRulesStorage()._getRulesArray(ruleSelector, isRequired);
    }

    function _encodeConfigureCall(
        uint256, /* entityId */
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(IGroupRule.configure, (configSalt, ruleParams));
    }

    function _emitGroupRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        uint256, /* entityId */
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal {
        if (wasAlreadyConfigured) {
            emit IGroup.Lens_Group_RuleReconfigured(ruleAddress, configSalt, ruleParams);
        } else {
            emit IGroup.Lens_Group_RuleConfigured(ruleAddress, configSalt, ruleParams);
        }
    }

    function _emitGroupRuleSelectorEvent(
        bool enabled,
        uint256, /* entityId */
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired,
        bytes4 ruleSelector
    ) internal {
        if (enabled) {
            emit Lens_Group_RuleSelectorEnabled(ruleAddress, configSalt, isRequired, ruleSelector);
        } else {
            emit Lens_Group_RuleSelectorDisabled(ruleAddress, configSalt, isRequired, ruleSelector);
        }
    }

    ////////////////////////////  PROCESSING FUNCTIONS  ////////////////////////////

    function _encodeAndCallProcessMemberRemoval(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IGroupRule.processRemoval,
                (configSalt, originalMsgSender, account, primitiveCustomParams, ruleCustomParams)
            )
        );
    }

    function _processMemberRemoval(
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) internal {
        _processGroupRule(
            _encodeAndCallProcessMemberRemoval,
            IGroupRule.processRemoval.selector,
            originalMsgSender,
            account,
            primitiveCustomParams,
            ruleProcessingParams
        );
    }

    function _encodeAndCallProcessMemberAddition(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IGroupRule.processAddition,
                (configSalt, originalMsgSender, account, primitiveCustomParams, ruleCustomParams)
            )
        );
    }

    function _processMemberAddition(
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) internal {
        _processGroupRule(
            _encodeAndCallProcessMemberAddition,
            IGroupRule.processAddition.selector,
            originalMsgSender,
            account,
            primitiveCustomParams,
            ruleProcessingParams
        );
    }

    function _encodeAndCallProcessMemberJoining(
        address rule,
        bytes32 configSalt,
        address, /* originalMsgSender */
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(IGroupRule.processJoining, (configSalt, account, primitiveCustomParams, ruleCustomParams))
        );
    }

    function _processMemberJoining(
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) internal {
        _processGroupRule(
            _encodeAndCallProcessMemberJoining,
            IGroupRule.processJoining.selector,
            originalMsgSender,
            account,
            primitiveCustomParams,
            ruleProcessingParams
        );
    }

    function _encodeAndCallProcessMemberLeaving(
        address rule,
        bytes32 configSalt,
        address, /* originalMsgSender */
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(IGroupRule.processLeaving, (configSalt, account, primitiveCustomParams, ruleCustomParams))
        );
    }

    function _processMemberLeaving(
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) internal {
        _processGroupRule(
            _encodeAndCallProcessMemberLeaving,
            IGroupRule.processLeaving.selector,
            originalMsgSender,
            account,
            primitiveCustomParams,
            ruleProcessingParams
        );
    }

    function _processGroupRule(
        function(address,bytes32,address,address,KeyValue[] calldata,KeyValue[] memory) internal returns (bool,bytes memory)
            encodeAndCall,
        bytes4 ruleSelector,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) private {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $groupRulesStorage().requiredRules[ruleSelector].length; i++) {
            Rule memory rule = $groupRulesStorage().requiredRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr, rule.configSalt, originalMsgSender, account, primitiveCustomParams, ruleParams
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $groupRulesStorage().anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = $groupRulesStorage().anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr, rule.configSalt, originalMsgSender, account, primitiveCustomParams, ruleParams
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($groupRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }
}
