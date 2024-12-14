// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroupRule} from "./../../interfaces/IGroupRule.sol";
import {IGroup} from "./../../interfaces/IGroup.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {
    RuleChange,
    RuleProcessingParams,
    RuleConfigurationParams,
    RuleConfigurationParams_Multiselector,
    Rule,
    RuleOperation,
    KeyValue
} from "./../../types/Types.sol";

abstract contract RuleBasedGroup is IGroup {
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

    // Public

    function changeGroupRules(RuleChange[] calldata ruleChanges) external virtual override {
        _beforeChangeGroupRules(ruleChanges);
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleConfigurationParams_Multiselector memory ruleConfig_Multiselector = ruleChanges[i].configuration;
            for (uint256 j = 0; j < ruleConfig_Multiselector.ruleSelectors.length; j++) {
                RuleConfigurationParams memory ruleConfig = RuleConfigurationParams({
                    ruleSelector: ruleConfig_Multiselector.ruleSelectors[j],
                    ruleAddress: ruleConfig_Multiselector.ruleAddress,
                    isRequired: ruleConfig_Multiselector.isRequired,
                    configSalt: ruleConfig_Multiselector.configSalt,
                    customParams: ruleConfig_Multiselector.customParams
                });
                if (ruleChanges[i].operation == RuleOperation.ADD) {
                    _addGroupRule(ruleConfig);
                    emit IGroup.Lens_Group_RuleAdded(
                        ruleConfig.ruleAddress,
                        ruleConfig.configSalt,
                        ruleConfig.ruleSelector,
                        ruleConfig.customParams,
                        ruleConfig.isRequired
                    );
                } else if (ruleChanges[i].operation == RuleOperation.UPDATE) {
                    _updateGroupRule(ruleConfig);
                    emit IGroup.Lens_Group_RuleUpdated(
                        ruleConfig.ruleAddress,
                        ruleConfig.configSalt,
                        ruleConfig.ruleSelector,
                        ruleConfig.customParams,
                        ruleConfig.isRequired
                    );
                } else {
                    _removeGroupRule(ruleConfig);
                    emit IGroup.Lens_Group_RuleRemoved(
                        ruleConfig.ruleAddress, ruleConfig.configSalt, ruleConfig.ruleSelector
                    );
                }
            }
        }
        require(
            $groupRulesStorage().anyOfRules[IGroupRule.processAddition.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $groupRulesStorage().anyOfRules[IGroupRule.processRemoval.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $groupRulesStorage().anyOfRules[IGroupRule.processJoining.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $groupRulesStorage().anyOfRules[IGroupRule.processLeaving.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
    }

    function getGroupRules(
        bytes4 ruleSelector,
        bool isRequired
    ) external view virtual override returns (Rule[] memory) {
        return $groupRulesStorage()._getRulesArray(ruleSelector, isRequired);
    }

    // Internal

    function _beforeChangeGroupRules(RuleChange[] calldata ruleChanges) internal virtual {}

    function _addGroupRule(RuleConfigurationParams memory rule) internal {
        $groupRulesStorage().addRule(
            rule, abi.encodeCall(IGroupRule.configure, (rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _updateGroupRule(RuleConfigurationParams memory rule) internal {
        $groupRulesStorage().updateRule(
            rule, abi.encodeCall(IGroupRule.configure, (rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _removeGroupRule(RuleConfigurationParams memory rule) internal {
        $groupRulesStorage().removeRule(rule);
    }

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
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr, rule.configSalt, originalMsgSender, account, primitiveCustomParams, ruleCustomParams
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $groupRulesStorage().anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = $groupRulesStorage().anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr, rule.configSalt, originalMsgSender, account, primitiveCustomParams, ruleCustomParams
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($groupRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }

    function _amountOfRules(bytes4 ruleSelector) internal view returns (uint256) {
        return $groupRulesStorage()._getRulesArray(ruleSelector, false).length
            + $groupRulesStorage()._getRulesArray(ruleSelector, true).length;
    }
}
