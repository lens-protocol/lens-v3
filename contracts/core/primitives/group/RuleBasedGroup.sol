// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {IGroup} from "contracts/core/interfaces/IGroup.sol";
import {RulesStorage, RulesLib} from "contracts/core/libraries/RulesLib.sol";
import {RuleChange, RuleProcessingParams, Rule, KeyValue} from "contracts/core/types/Types.sol";
import {RuleBasedPrimitive} from "contracts/core/base/RuleBasedPrimitive.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";
import {Errors} from "contracts/core/types/Errors.sol";

abstract contract RuleBasedGroup is IGroup, RuleBasedPrimitive {
    using RulesLib for RulesStorage;
    using CallLib for address;

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

    function _encodePrimitiveConfigureCall(bytes32 configSalt, KeyValue[] memory ruleParams)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encodeCall(IGroupRule.configure, (configSalt, ruleParams));
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
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IGroupRule.processRemoval,
                (
                    rule.configSalt,
                    processParams.originalMsgSender,
                    processParams.account,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _processMemberRemoval(
        address originalMsgSender,
        address account,
        KeyValue[] memory primitiveCustomParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) internal {
        _processGroupRule(
            _encodeAndCallProcessMemberRemoval,
            ProcessParams({
                ruleSelector: IGroupRule.processRemoval.selector,
                originalMsgSender: originalMsgSender,
                account: account,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: ruleProcessingParams
            })
        );
    }

    function _encodeAndCallProcessMemberAddition(
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IGroupRule.processAddition,
                (
                    rule.configSalt,
                    processParams.originalMsgSender,
                    processParams.account,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _processMemberAddition(
        address originalMsgSender,
        address account,
        KeyValue[] memory primitiveCustomParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) internal {
        _processGroupRule(
            _encodeAndCallProcessMemberAddition,
            ProcessParams({
                ruleSelector: IGroupRule.processAddition.selector,
                originalMsgSender: originalMsgSender,
                account: account,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: ruleProcessingParams
            })
        );
    }

    function _encodeAndCallProcessMemberJoining(
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IGroupRule.processJoining,
                (rule.configSalt, processParams.account, processParams.primitiveCustomParams, ruleParams)
            )
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
            ProcessParams({
                ruleSelector: IGroupRule.processJoining.selector,
                originalMsgSender: originalMsgSender,
                account: account,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: ruleProcessingParams
            })
        );
    }

    function _encodeAndCallProcessMemberLeaving(
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IGroupRule.processLeaving,
                (rule.configSalt, processParams.account, processParams.primitiveCustomParams, ruleParams)
            )
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
            ProcessParams({
                ruleSelector: IGroupRule.processLeaving.selector,
                originalMsgSender: originalMsgSender,
                account: account,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: ruleProcessingParams
            })
        );
    }

    struct ProcessParams {
        bytes4 ruleSelector;
        address originalMsgSender;
        address account;
        KeyValue[] primitiveCustomParams;
        RuleProcessingParams[] rulesProcessingParams;
    }

    function _processGroupRule(
        function(Rule memory,ProcessParams memory,KeyValue[] memory) internal returns (bool,bytes memory) encodeAndCall,
        ProcessParams memory processParams
    ) private {
        Rule memory rule;
        KeyValue[] memory ruleParams;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $groupRulesStorage().requiredRules[processParams.ruleSelector].length; i++) {
            rule = $groupRulesStorage().requiredRules[processParams.ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            require(callSucceeded, Errors.RequiredRuleReverted());
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $groupRulesStorage().anyOfRules[processParams.ruleSelector].length; i++) {
            rule = $groupRulesStorage().anyOfRules[processParams.ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            if (callSucceeded) {
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($groupRulesStorage().anyOfRules[processParams.ruleSelector].length == 0, Errors.AllAnyOfRulesReverted());
    }
}
