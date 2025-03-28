// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IFollowRule} from "contracts/core/interfaces/IFollowRule.sol";
import {IGraphRule} from "contracts/core/interfaces/IGraphRule.sol";
import {RulesStorage, RulesLib} from "contracts/core/libraries/RulesLib.sol";
import {RuleProcessingParams, RuleChange, Rule, KeyValue} from "contracts/core/types/Types.sol";
import {IGraph} from "contracts/core/interfaces/IGraph.sol";
import {RuleBasedPrimitive} from "contracts/core/base/RuleBasedPrimitive.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";
import {Errors} from "contracts/core/types/Errors.sol";

abstract contract RuleBasedGraph is IGraph, RuleBasedPrimitive {
    using RulesLib for RulesStorage;
    using CallLib for address;

    struct RuleBasedStorage {
        RulesStorage graphRulesStorage;
        mapping(address => RulesStorage) followRulesStorage;
    }

    /// @custom:keccak lens.storage.RuleBasedGraph
    bytes32 constant STORAGE__RULE_BASED_GRAPH = 0x6644773a6cb3d68b635cf6054580d77eff2d2b0b6851802f2c6d1adbf85026f9;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__RULE_BASED_GRAPH
        }
    }

    function $graphRulesStorage() private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().graphRulesStorage;
    }

    function $followRulesStorage(address account) private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().followRulesStorage[account];
    }

    ////////////////////////////  CONFIGURATION FUNCTIONS  ////////////////////////////

    function changeGraphRules(RuleChange[] calldata ruleChanges) external virtual override {
        _changePrimitiveRules($graphRulesStorage(), ruleChanges);
    }

    function changeFollowRules(
        address account,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] calldata ruleChangesProcessingParams
    ) external virtual override {
        _changeEntityRules(
            $followRulesStorage(account), uint256(uint160(account)), ruleChanges, ruleChangesProcessingParams
        );
    }

    function _processEntityRulesChanges(
        uint256 entityId,
        RuleChange[] memory ruleChanges,
        RuleProcessingParams[] memory ruleChangesProcessingParams
    ) internal virtual override {
        _graphProcessFollowRuleChanges(address(uint160(entityId)), ruleChanges, ruleChangesProcessingParams);
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = IGraphRule.processFollow.selector;
        selectors[1] = IGraphRule.processUnfollow.selector;
        selectors[2] = IGraphRule.processFollowRuleChanges.selector;
        return selectors;
    }

    function _supportedEntityRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IFollowRule.processFollow.selector;
        return selectors;
    }

    function _encodePrimitiveConfigureCall(bytes32 configSalt, KeyValue[] memory ruleParams)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encodeCall(IGraphRule.configure, (configSalt, ruleParams));
    }

    function _encodeEntityConfigureCall(uint256 accountAsUint256, bytes32 configSalt, KeyValue[] memory ruleParams)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encodeCall(IFollowRule.configure, (configSalt, address(uint160(accountAsUint256)), ruleParams));
    }

    function _emitPrimitiveRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] memory ruleParams
    ) internal override {
        if (wasAlreadyConfigured) {
            emit IGraph.Lens_Graph_RuleReconfigured(ruleAddress, configSalt, ruleParams);
        } else {
            emit IGraph.Lens_Graph_RuleConfigured(ruleAddress, configSalt, ruleParams);
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
            emit Lens_Graph_RuleSelectorEnabled(ruleAddress, configSalt, isRequired, ruleSelector);
        } else {
            emit Lens_Graph_RuleSelectorDisabled(ruleAddress, configSalt, isRequired, ruleSelector);
        }
    }

    function _emitEntityRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] memory ruleParams
    ) internal override {
        address account = address(uint160(entityId));
        if (wasAlreadyConfigured) {
            emit IGraph.Lens_Graph_Follow_RuleReconfigured(account, ruleAddress, configSalt, ruleParams);
        } else {
            emit IGraph.Lens_Graph_Follow_RuleConfigured(account, ruleAddress, configSalt, ruleParams);
        }
    }

    function _emitEntityRuleSelectorEvent(
        bool enabled,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired,
        bytes4 selector
    ) internal override {
        address account = address(uint160(entityId));
        if (enabled) {
            emit IGraph.Lens_Graph_Follow_RuleSelectorEnabled(account, ruleAddress, configSalt, isRequired, selector);
        } else {
            emit IGraph.Lens_Graph_Follow_RuleSelectorDisabled(account, ruleAddress, configSalt, isRequired, selector);
        }
    }

    function getGraphRules(bytes4 ruleSelector, bool isRequired)
        external
        view
        virtual
        override
        returns (Rule[] memory)
    {
        return $graphRulesStorage()._getRulesArray(ruleSelector, isRequired);
    }

    function getFollowRules(address account, bytes4 ruleSelector, bool isRequired)
        external
        view
        virtual
        override
        returns (Rule[] memory)
    {
        return $followRulesStorage(account)._getRulesArray(ruleSelector, isRequired);
    }

    // Internal

    function _graphProcessFollowRuleChanges(
        address account,
        RuleChange[] memory ruleChanges,
        RuleProcessingParams[] memory graphRulesProcessingParams
    ) internal {
        bytes4 ruleSelector = IGraphRule.processFollowRuleChanges.selector;
        Rule memory rule;
        KeyValue[] memory ruleParams;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $graphRulesStorage().requiredRules[ruleSelector].length; i++) {
            rule = $graphRulesStorage().requiredRules[ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, graphRulesProcessingParams);
            (bool callSucceeded,) = rule.ruleAddress.safecall(
                abi.encodeCall(IGraphRule.processFollowRuleChanges, (rule.configSalt, account, ruleChanges, ruleParams))
            );
            require(callSucceeded, Errors.RequiredRuleReverted());
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $graphRulesStorage().anyOfRules[ruleSelector].length; i++) {
            rule = $graphRulesStorage().anyOfRules[ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, graphRulesProcessingParams);
            (bool callSucceeded,) = rule.ruleAddress.safecall(
                abi.encodeCall(IGraphRule.processFollowRuleChanges, (rule.configSalt, account, ruleChanges, ruleParams))
            );
            if (callSucceeded) {
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($graphRulesStorage().anyOfRules[ruleSelector].length == 0, Errors.AllAnyOfRulesReverted());
    }

    struct ProcessParams {
        address originalMsgSender;
        address sourceAccount;
        address targetAccount;
        KeyValue[] primitiveCustomParams;
        RuleProcessingParams[] rulesProcessingParams;
    }

    function _encodeAndCallGraphProcessFollow(
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IGraphRule.processFollow,
                (
                    rule.configSalt,
                    processParams.originalMsgSender,
                    processParams.sourceAccount,
                    processParams.targetAccount,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _graphProcessFollow(
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        _processFollow(
            $graphRulesStorage(),
            _encodeAndCallGraphProcessFollow,
            IGraphRule.processFollow.selector,
            ProcessParams({
                originalMsgSender: originalMsgSender,
                sourceAccount: followerAccount,
                targetAccount: accountToFollow,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: rulesProcessingParams
            })
        );
    }

    function _encodeAndCallGraphProcessUnfollow(
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IGraphRule.processUnfollow,
                (
                    rule.configSalt,
                    processParams.originalMsgSender,
                    processParams.sourceAccount,
                    processParams.targetAccount,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _graphProcessUnfollow(
        address originalMsgSender,
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        _processUnfollow(
            $graphRulesStorage(),
            _encodeAndCallGraphProcessUnfollow,
            ProcessParams({
                originalMsgSender: originalMsgSender,
                sourceAccount: followerAccount,
                targetAccount: accountToUnfollow,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: rulesProcessingParams
            })
        );
    }

    function _encodeAndCallAccountProcessFollow(
        Rule memory rule,
        ProcessParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IFollowRule.processFollow,
                (
                    rule.configSalt,
                    processParams.originalMsgSender,
                    processParams.sourceAccount,
                    processParams.targetAccount,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _accountProcessFollow(
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        _processFollow(
            $followRulesStorage(accountToFollow),
            _encodeAndCallAccountProcessFollow,
            IFollowRule.processFollow.selector,
            ProcessParams({
                originalMsgSender: originalMsgSender,
                sourceAccount: followerAccount,
                targetAccount: accountToFollow,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: rulesProcessingParams
            })
        );
    }

    function _processUnfollow(
        RulesStorage storage rulesStorage,
        function(Rule memory,ProcessParams memory,KeyValue[] memory) internal returns (bool,bytes memory) encodeAndCall,
        ProcessParams memory processParams
    ) internal {
        bytes4 ruleSelector = IGraphRule.processUnfollow.selector;
        Rule memory rule;
        KeyValue[] memory ruleParams;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < rulesStorage.requiredRules[ruleSelector].length; i++) {
            rule = rulesStorage.requiredRules[ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            require(callSucceeded, Errors.RequiredRuleReverted());
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < rulesStorage.anyOfRules[ruleSelector].length; i++) {
            rule = rulesStorage.anyOfRules[ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            if (callSucceeded) {
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require(rulesStorage.anyOfRules[ruleSelector].length == 0, Errors.AllAnyOfRulesReverted());
    }

    function _processFollow(
        RulesStorage storage rulesStorage,
        function(Rule memory,ProcessParams memory,KeyValue[] memory) internal returns (bool,bytes memory) encodeAndCall,
        bytes4 ruleSelector,
        ProcessParams memory processParams
    ) internal {
        Rule memory rule;
        KeyValue[] memory ruleParams;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < rulesStorage.requiredRules[ruleSelector].length; i++) {
            rule = rulesStorage.requiredRules[ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            require(callSucceeded, Errors.RequiredRuleReverted());
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < rulesStorage.anyOfRules[ruleSelector].length; i++) {
            rule = rulesStorage.anyOfRules[ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            if (callSucceeded) {
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require(rulesStorage.anyOfRules[ruleSelector].length == 0, Errors.AllAnyOfRulesReverted());
    }
}
