// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroupRule} from "./../../interfaces/IGroupRule.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "./../../types/Types.sol";

contract RuleBasedGroup {
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

    function changeGroupRules(RuleChange[] calldata ruleChanges) external override {
        _beforeChangeGroupRules(ruleChanges);
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleParams memory ruleConfig = ruleChanges[i].configuration;
            if (ruleChanges[i].operation == RuleOperation.ADD) {
                _addGroupRule(ruleConfig);
                emit Lens_Group_RuleAdded(
                    ruleConfig.ruleAddress, ruleConfig.configSalt, ruleConfig.configData, ruleConfig.isRequired
                );
            } else if (ruleChanges[i].operation == RuleOperation.UPDATE) {
                _updateGroupRule(ruleConfig);
                emit Lens_Group_RuleUpdated(
                    ruleConfig.ruleAddress, ruleConfig.configSalt, ruleConfig.configData, ruleConfig.isRequired
                );
            } else {
                _removeGroupRule(ruleConfig);
                emit Lens_Group_RuleRemoved(ruleConfig.ruleAddress, ruleConfig.configSalt);
            }
        }
        require(
            $groupRulesStorage().anyOfRules[IGroupRule.processMemberAddition.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $groupRulesStorage().anyOfRules[IGroupRule.processMemberRemoval.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $groupRulesStorage().anyOfRules[IGroupRule.processMemberJoining.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $groupRulesStorage().anyOfRules[IGroupRule.processMemberLeaving.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
    }

    // Internal

    function _beforeChangeGroupRules(RuleChange[] calldata ruleChanges) internal virtual {}

    function _addGroupRule(RuleParams memory rule) internal {
        $groupRulesStorage().addRule(
            rule, abi.encodeCall(IGroupRule.configure, (rule.selector, rule.configSalt, rule.customParams))
        );
    }

    function _updateGroupRule(RuleParams memory rule) internal {
        $groupRulesStorage().updateRule(
            rule, abi.encodeCall(IGroupRule.configure, (rule.selector, rule.configSalt, rule.customParams))
        );
    }

    function _removeGroupRule(RuleParams memory rule) internal {
        $groupRulesStorage().removeRule(rule);
    }

    function _encodeAndCallProcessMemberRemoval(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IGroupRule.processMemberRemoval,
                (configSalt, originalMsgSender, account, primitiveCustomParams, ruleCustomParams)
            )
        );
    }

    function _processMemberRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleCustomParams
    ) internal {
        _processGroupRule(
            _encodeAndCallProcessMemberRemoval,
            IGroupRule.processMemberRemoval.selector,
            configSalt,
            originalMsgSender,
            account,
            primitiveCustomParams,
            ruleCustomParams
        );
    }

    function _encodeAndCallProcessMemberAddition(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IGroupRule.processMemberAddition,
                (configSalt, originalMsgSender, account, primitiveCustomParams, ruleCustomParams)
            )
        );
    }

    function _processMemberAddition(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleCustomParams
    ) internal {
        _processGroupRule(
            _encodeAndCallProcessMemberAddition,
            IGroupRule.processMemberAddition.selector,
            configSalt,
            originalMsgSender,
            account,
            primitiveCustomParams,
            ruleCustomParams
        );
    }

    function _encodeAndCallProcessMemberJoining(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IGroupRule.processMemberJoining,
                (configSalt, originalMsgSender, account, primitiveCustomParams, ruleCustomParams)
            )
        );
    }

    function _processMemberJoining(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleCustomParams
    ) internal {
        _processGroupRule(
            _encodeAndCallProcessMemberJoining,
            IGroupRule.processMemberJoining.selector,
            configSalt,
            originalMsgSender,
            account,
            primitiveCustomParams,
            ruleCustomParams
        );
    }

    function _encodeAndCallProcessMemberLeaving(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IGroupRule.processMemberLeaving,
                (configSalt, originalMsgSender, account, primitiveCustomParams, ruleCustomParams)
            )
        );
    }

    function _processMemberLeaving(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleCustomParams
    ) internal {
        _processGroupRule(
            _encodeAndCallProcessMemberLeaving,
            IGroupRule.processMemberLeaving.selector,
            configSalt,
            originalMsgSender,
            account,
            primitiveCustomParams,
            ruleCustomParams
        );
    }

    function _processGroupRule(
        function(bytes32,address,address,KeyValue[] calldata,KeyValue[] calldata) internal returns (bool,bytes memory)
            encodeAndCall,
        bytes4 ruleSelector,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) private {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $groupRulesStorage().requiredRules[ruleSelector].length; i++) {
            Rule memory rule = $groupRulesStorage().rules[ruleAddress][configSalt];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[]();
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.ruleAddress,
                    rule.configSalt,
                    originalMsgSender,
                    account,
                    primitiveCustomParams,
                    ruleCustomParams
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $groupRulesStorage().anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = $groupRulesStorage().rules[ruleAddress][configSalt];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[]();
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted, bytes memory returnData) = encodeAndCall(
                    rule.ruleAddress,
                    rule.configSalt,
                    originalMsgSender,
                    account,
                    primitiveCustomParams,
                    ruleCustomParams
                );
                if (callNotReverted && abi.decode(returnData, (bool))) {
                    // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        revert($groupRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }

    function getGroupRules(bytes4 ruleSelector, bool isRequired) external view override returns (Rule[] memory) {
        return $groupRulesStorage().getRulesArray(isRequired);
    }
}
