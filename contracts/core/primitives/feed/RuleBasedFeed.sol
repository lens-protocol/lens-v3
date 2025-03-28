// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IPostRule} from "contracts/core/interfaces/IPostRule.sol";
import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {RulesStorage, RulesLib} from "contracts/core/libraries/RulesLib.sol";
import {RuleProcessingParams, Rule, RuleChange, KeyValue} from "contracts/core/types/Types.sol";
import {EditPostParams, CreatePostParams} from "contracts/core/interfaces/IFeed.sol";
import {RuleBasedPrimitive} from "contracts/core/base/RuleBasedPrimitive.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";
import {Errors} from "contracts/core/types/Errors.sol";

abstract contract RuleBasedFeed is IFeed, RuleBasedPrimitive {
    using RulesLib for RulesStorage;
    using CallLib for address;

    struct RuleBasedStorage {
        RulesStorage feedRulesStorage;
        mapping(uint256 => RulesStorage) postRulesStorage;
    }

    /// @custom:keccak lens.storage.RuleBasedStorage
    bytes32 constant STORAGE__RULE_BASED_FEED = 0x5d84583cb768017b44ca3aec8199901a24d17ed118ff103b086430f4dac47b71;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__RULE_BASED_FEED
        }
    }

    function $feedRulesStorage() private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().feedRulesStorage;
    }

    function $postRulesStorage(uint256 postId) private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().postRulesStorage[postId];
    }

    ////////////////////////////  CONFIGURATION FUNCTIONS  ////////////////////////////

    function changeFeedRules(RuleChange[] calldata ruleChanges) external virtual override {
        _changePrimitiveRules($feedRulesStorage(), ruleChanges);
    }

    function changePostRules(
        uint256 postId,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] calldata feedRulesParams
    ) external virtual override {
        _changeEntityRules($postRulesStorage(postId), postId, ruleChanges, feedRulesParams);
    }

    function _processEntityRulesChanges(
        uint256 postId,
        RuleChange[] memory ruleChanges,
        RuleProcessingParams[] memory feedRulesParams
    ) internal virtual override {
        _processPostRulesChanges(postId, ruleChanges, feedRulesParams);
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IFeedRule.processCreatePost.selector;
        selectors[1] = IFeedRule.processEditPost.selector;
        selectors[2] = IFeedRule.processDeletePost.selector;
        selectors[3] = IFeedRule.processPostRuleChanges.selector;
        return selectors;
    }

    function _supportedEntityRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IPostRule.processCreatePost.selector;
        selectors[1] = IPostRule.processEditPost.selector;
        return selectors;
    }

    function _encodePrimitiveConfigureCall(bytes32 configSalt, KeyValue[] memory ruleParams)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encodeCall(IFeedRule.configure, (configSalt, ruleParams));
    }

    function _encodeEntityConfigureCall(uint256 postId, bytes32 configSalt, KeyValue[] memory ruleParams)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encodeCall(IPostRule.configure, (configSalt, postId, ruleParams));
    }

    function _emitPrimitiveRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] memory ruleParams
    ) internal override {
        if (wasAlreadyConfigured) {
            emit IFeed.Lens_Feed_RuleReconfigured(ruleAddress, configSalt, ruleParams);
        } else {
            emit IFeed.Lens_Feed_RuleConfigured(ruleAddress, configSalt, ruleParams);
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
            emit Lens_Feed_RuleSelectorEnabled(ruleAddress, configSalt, isRequired, ruleSelector);
        } else {
            emit Lens_Feed_RuleSelectorDisabled(ruleAddress, configSalt, isRequired, ruleSelector);
        }
    }

    function _emitEntityRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        uint256 entityId,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] memory ruleParams
    ) internal override {
        if (wasAlreadyConfigured) {
            emit IFeed.Lens_Feed_Post_RuleReconfigured(entityId, msg.sender, ruleAddress, configSalt, ruleParams);
        } else {
            emit IFeed.Lens_Feed_Post_RuleConfigured(entityId, msg.sender, ruleAddress, configSalt, ruleParams);
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
        if (enabled) {
            emit IFeed.Lens_Feed_Post_RuleSelectorEnabled(
                entityId, msg.sender, ruleAddress, configSalt, isRequired, selector
            );
        } else {
            emit IFeed.Lens_Feed_Post_RuleSelectorDisabled(
                entityId, msg.sender, ruleAddress, configSalt, isRequired, selector
            );
        }
    }

    function getFeedRules(bytes4 ruleSelector, bool isRequired) external view virtual override returns (Rule[] memory) {
        return $feedRulesStorage()._getRulesArray(ruleSelector, isRequired);
    }

    function getPostRules(bytes4 ruleSelector, uint256 postId, bool isRequired)
        external
        view
        virtual
        override
        returns (Rule[] memory)
    {
        return $postRulesStorage(postId)._getRulesArray(ruleSelector, isRequired);
    }

    /////////////////////////////////////////////////////////////////////////////

    function _addPostRulesAtCreation(
        uint256 postId,
        CreatePostParams memory postParams,
        RuleProcessingParams[] memory feedRulesParams
    ) internal {
        _changeEntityRules($postRulesStorage(postId), postId, postParams.ruleChanges, feedRulesParams);
    }

    // Internal

    function _encodeAndCallProcessCreatePostOnFeed(
        Rule memory rule,
        ProcessPostCreationParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IFeedRule.processCreatePost,
                (
                    rule.configSalt,
                    processParams.postId,
                    processParams.postParams,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _encodeAndCallProcessCreatePostOnRootPost(
        Rule memory rule,
        ProcessPostCreationParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IPostRule.processCreatePost,
                (
                    rule.configSalt,
                    processParams.rootPostId,
                    processParams.postId,
                    processParams.postParams,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    struct ProcessPostCreationParams {
        bytes4 ruleSelector;
        uint256 rootPostId;
        uint256 postId;
        CreatePostParams postParams;
        KeyValue[] primitiveCustomParams;
        RuleProcessingParams[] rulesProcessingParams;
    }

    function _processPostCreation(
        function(Rule memory,ProcessPostCreationParams memory,KeyValue[] memory) internal returns (bool, bytes memory)
            encodeAndCall,
        ProcessPostCreationParams memory processParams
    ) internal {
        RulesStorage storage _rulesStorage =
            processParams.rootPostId == 0 ? $feedRulesStorage() : $postRulesStorage(processParams.rootPostId);
        Rule memory rule;
        KeyValue[] memory ruleParams;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < _rulesStorage.requiredRules[processParams.ruleSelector].length; i++) {
            rule = _rulesStorage.requiredRules[processParams.ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            require(callSucceeded, Errors.RequiredRuleReverted());
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < _rulesStorage.anyOfRules[processParams.ruleSelector].length; i++) {
            rule = _rulesStorage.anyOfRules[processParams.ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            if (callSucceeded) {
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require(_rulesStorage.anyOfRules[processParams.ruleSelector].length == 0, Errors.AllAnyOfRulesReverted());
    }

    function _processPostCreationOnRootPost(
        uint256 rootPostId,
        uint256 postId,
        CreatePostParams memory postParams,
        KeyValue[] memory primitiveCustomParams,
        RuleProcessingParams[] memory postRulesParams
    ) internal {
        _processPostCreation(
            _encodeAndCallProcessCreatePostOnRootPost,
            ProcessPostCreationParams({
                ruleSelector: IPostRule.processCreatePost.selector,
                rootPostId: rootPostId,
                postId: postId,
                postParams: postParams,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: postRulesParams
            })
        );
    }

    function _processPostCreationOnFeed(
        uint256 postId,
        CreatePostParams memory postParams,
        KeyValue[] memory primitiveCustomParams,
        RuleProcessingParams[] memory feedRulesParams
    ) internal {
        _processPostCreation(
            _encodeAndCallProcessCreatePostOnFeed,
            ProcessPostCreationParams({
                ruleSelector: IFeedRule.processCreatePost.selector,
                rootPostId: 0,
                postId: postId,
                postParams: postParams,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: feedRulesParams
            })
        );
    }

    function _processPostEditingOnRootPost(
        uint256 rootPostId,
        uint256 postId,
        EditPostParams memory postParams,
        KeyValue[] memory primitiveCustomParams,
        RuleProcessingParams[] memory postRulesParams
    ) internal {
        _processPostEditing(
            _encodeAndCallProcessEditPostOnRootPost,
            ProcessPostEditingParams({
                ruleSelector: IPostRule.processEditPost.selector,
                rootPostId: rootPostId,
                postId: postId,
                postParams: postParams,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: postRulesParams
            })
        );
    }

    function _processPostEditingOnFeed(
        uint256 postId,
        EditPostParams memory postParams,
        KeyValue[] memory primitiveCustomParams,
        RuleProcessingParams[] memory feedRulesParams
    ) internal {
        _processPostEditing(
            _encodeAndCallProcessEditPostOnFeed,
            ProcessPostEditingParams({
                ruleSelector: IFeedRule.processEditPost.selector,
                rootPostId: 0,
                postId: postId,
                postParams: postParams,
                primitiveCustomParams: primitiveCustomParams,
                rulesProcessingParams: feedRulesParams
            })
        );
    }

    function _encodeAndCallProcessEditPostOnFeed(
        Rule memory rule,
        ProcessPostEditingParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IFeedRule.processEditPost,
                (
                    rule.configSalt,
                    processParams.postId,
                    processParams.postParams,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    function _encodeAndCallProcessEditPostOnRootPost(
        Rule memory rule,
        ProcessPostEditingParams memory processParams,
        KeyValue[] memory ruleParams
    ) internal returns (bool, bytes memory) {
        return rule.ruleAddress.safecall(
            abi.encodeCall(
                IPostRule.processEditPost,
                (
                    rule.configSalt,
                    processParams.rootPostId,
                    processParams.postId,
                    processParams.postParams,
                    processParams.primitiveCustomParams,
                    ruleParams
                )
            )
        );
    }

    struct ProcessPostEditingParams {
        bytes4 ruleSelector;
        uint256 rootPostId;
        uint256 postId;
        EditPostParams postParams;
        KeyValue[] primitiveCustomParams;
        RuleProcessingParams[] rulesProcessingParams;
    }

    function _processPostEditing(
        function(Rule memory,ProcessPostEditingParams memory,KeyValue[] memory) internal returns (bool,bytes memory)
            encodeAndCall,
        ProcessPostEditingParams memory processParams
    ) internal {
        RulesStorage storage _rulesStorage =
            processParams.rootPostId == 0 ? $feedRulesStorage() : $postRulesStorage(processParams.rootPostId);
        Rule memory rule;
        KeyValue[] memory ruleParams;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < _rulesStorage.requiredRules[processParams.ruleSelector].length; i++) {
            rule = _rulesStorage.requiredRules[processParams.ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            require(callSucceeded, Errors.RequiredRuleReverted());
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < _rulesStorage.anyOfRules[processParams.ruleSelector].length; i++) {
            rule = _rulesStorage.anyOfRules[processParams.ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, processParams.rulesProcessingParams);
            (bool callSucceeded,) = encodeAndCall(rule, processParams, ruleParams);
            if (callSucceeded) {
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require(_rulesStorage.anyOfRules[processParams.ruleSelector].length == 0, Errors.AllAnyOfRulesReverted());
    }

    function _processPostDeletion(
        uint256 postId,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        bytes4 ruleSelector = IFeedRule.processDeletePost.selector;
        Rule memory rule;
        KeyValue[] memory ruleParams;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules[ruleSelector].length; i++) {
            rule = $feedRulesStorage().requiredRules[ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, rulesProcessingParams);
            (bool callSucceeded,) = rule.ruleAddress.safecall(
                abi.encodeCall(IFeedRule.processDeletePost, (rule.configSalt, postId, customParams, ruleParams))
            );
            require(callSucceeded, Errors.RequiredRuleReverted());
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().anyOfRules[ruleSelector].length; i++) {
            rule = $feedRulesStorage().anyOfRules[ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, rulesProcessingParams);
            (bool callSucceeded,) = rule.ruleAddress.safecall(
                abi.encodeCall(IFeedRule.processDeletePost, (rule.configSalt, postId, customParams, ruleParams))
            );
            if (callSucceeded) {
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($feedRulesStorage().anyOfRules[ruleSelector].length == 0, Errors.AllAnyOfRulesReverted());
    }

    function _processPostRulesChanges(
        uint256 postId,
        RuleChange[] memory ruleChanges,
        RuleProcessingParams[] memory rulesProcessingParams
    ) internal {
        bytes4 ruleSelector = IFeedRule.processPostRuleChanges.selector;
        Rule memory rule;
        KeyValue[] memory ruleParams;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules[ruleSelector].length; i++) {
            rule = $feedRulesStorage().requiredRules[ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, rulesProcessingParams);
            (bool callSucceeded,) = rule.ruleAddress.safecall(
                abi.encodeCall(IFeedRule.processPostRuleChanges, (rule.configSalt, postId, ruleChanges, ruleParams))
            );
            require(callSucceeded, Errors.RequiredRuleReverted());
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().anyOfRules[ruleSelector].length; i++) {
            rule = $feedRulesStorage().anyOfRules[ruleSelector][i];
            ruleParams = _getRuleParamsOrEmptyArray(rule, rulesProcessingParams);
            (bool callSucceeded,) = rule.ruleAddress.safecall(
                abi.encodeCall(IFeedRule.processPostRuleChanges, (rule.configSalt, postId, ruleChanges, ruleParams))
            );
            if (callSucceeded) {
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($feedRulesStorage().anyOfRules[ruleSelector].length == 0, Errors.AllAnyOfRulesReverted());
    }
}
