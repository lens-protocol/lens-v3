// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroupRule} from "./../../interfaces/IGroupRule.sol";
import {IGroup} from "./../../interfaces/IGroup.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {RuleChange, RuleProcessingParams, Rule, KeyValue} from "./../../types/Types.sol";
import {RuleBasedPrimitive} from "./../../base/RuleBasedPrimitive.sol";

abstract contract RuleBasedGroup is IGroup, RuleBasedPrimitive {
    using RulesLib for RulesStorage;

    struct RuleBasedStorage {
        RulesStorage groupRulesStorage;
    }

    /// @custom:keccak lens.storage.RuleBasedGroup
    bytes32 constant STORAGE__RULE_BASED_GROUP = 0x99daa1bc32e51d43348d6cfb165a280fbe2c093a37fe63320452612b9fb73547;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__RULE_BASED_GROUP
        }
    }

    function $groupRulesStorage() private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().groupRulesStorage;
    }

    ////////////////////////////  CONFIGURATION FUNCTIONS  ////////////////////////////

    function changeGroupRules(RuleChange[] calldata ruleChanges) external virtual override {
        _changePrimitiveRules($groupRulesStorage(), ruleChanges);
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IGroupRule.processAddition.selector;
        selectors[1] = IGroupRule.processRemoval.selector;
        selectors[2] = IGroupRule.processJoining.selector;
        selectors[3] = IGroupRule.processLeaving.selector;
        return selectors;
    }

    function _encodePrimitiveConfigureCall(bytes32 configSalt, KeyValue[] calldata ruleParams)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encodeCall(IGroupRule.configure, (configSalt, ruleParams));
    }

    function _emitPrimitiveRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal override {
        if (wasAlreadyConfigured) {
            emit IGroup.Lens_Group_RuleReconfigured(ruleAddress, configSalt, ruleParams);
        } else {
            emit IGroup.Lens_Group_RuleConfigured(ruleAddress, configSalt, ruleParams);
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
            emit Lens_Group_RuleSelectorEnabled(ruleAddress, configSalt, isRequired, ruleSelector);
        } else {
            emit Lens_Group_RuleSelectorDisabled(ruleAddress, configSalt, isRequired, ruleSelector);
        }
    }

    function _amountOfRules(bytes4 ruleSelector) internal view returns (uint256) {
        return $groupRulesStorage()._getRulesArray(ruleSelector, false).length
            + $groupRulesStorage()._getRulesArray(ruleSelector, true).length;
    }

    function getGroupRules(bytes4 ruleSelector, bool isRequired)
        external
        view
        virtual
        override
        returns (Rule[] memory)
    {
        return $groupRulesStorage()._getRulesArray(ruleSelector, isRequired);
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
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.ruleAddress, rule.configSalt, originalMsgSender, account, primitiveCustomParams, ruleParams
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
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.ruleAddress, rule.configSalt, originalMsgSender, account, primitiveCustomParams, ruleParams
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($groupRulesStorage().anyOfRules[ruleSelector].length == 0, "All of the any-of rules failed");
    }
}
