// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IPostRule} from "./../../interfaces/IPostRule.sol";
import {IFeedRule} from "./../../interfaces/IFeedRule.sol";
import {IFeed} from "./../../interfaces/IFeed.sol";
import {FeedCore as Core} from "./FeedCore.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {RuleProcessingParams, Rule, RuleChange, KeyValue} from "./../../types/Types.sol";
import {EditPostParams, CreatePostParams} from "./../../interfaces/IFeed.sol";
import {RuleBasedPrimitive} from "./../../base/RuleBasedPrimitive.sol";

abstract contract RuleBasedFeed is IFeed, RuleBasedPrimitive {
    using RulesLib for RulesStorage;

    struct RuleBasedStorage {
        RulesStorage feedRulesStorage;
        mapping(uint256 => RulesStorage) postRulesStorage;
    }

    // keccak256('lens.rule.based.feed.storage')
    bytes32 constant RULE_BASED_FEED_STORAGE_SLOT = 0x02d31ef96f666bf684ab1c8a89d21f38a88719152ba49251cdaacb4c11cdae39;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := RULE_BASED_FEED_STORAGE_SLOT
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
        RuleProcessingParams[] calldata ruleChangesProcessingParams
    ) external virtual override {
        // TODO: msg.sender must be author
        // TODO: Post must exist before we allow changing its rules
        _changeEntityRules($postRulesStorage(postId), postId, ruleChanges, ruleChangesProcessingParams);
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IFeedRule.processCreatePost.selector;
        selectors[1] = IFeedRule.processEditPost.selector;
        selectors[2] = IFeedRule.processRemovePost.selector;
        selectors[3] = IFeedRule.processPostRuleChanges.selector;
        return selectors;
    }

    function _supportedEntityRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IPostRule.processCreatePost.selector;
        selectors[1] = IPostRule.processEditPost.selector;
        return selectors;
    }

    function _encodePrimitiveConfigureCall(
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal pure override returns (bytes memory) {
        return abi.encodeCall(IFeedRule.configure, (configSalt, ruleParams));
    }

    function _emitPrimitiveRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
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

    function _amountOfRules(bytes4 ruleSelector) internal view returns (uint256) {
        return $feedRulesStorage()._getRulesArray(ruleSelector, false).length
            + $feedRulesStorage()._getRulesArray(ruleSelector, true).length;
    }

    function getFeedRules(bytes4 ruleSelector, bool isRequired) external view virtual override returns (Rule[] memory) {
        return $feedRulesStorage()._getRulesArray(ruleSelector, isRequired);
    }

    function getPostRules(
        bytes4 ruleSelector,
        uint256 postId,
        bool isRequired
    ) external view virtual override returns (Rule[] memory) {
        return $postRulesStorage(postId)._getRulesArray(ruleSelector, isRequired);
    }

    /////////////////////////////////////////////////////////////////////////////

    function _addPostRulesAtCreation(
        uint256 postId,
        CreatePostParams calldata postParams,
        RuleProcessingParams[] calldata feedRulesParams
    ) internal {
        _changeEntityRules($postRulesStorage(postId), postId, postParams.ruleChanges, feedRulesParams);
    }

    // Internal

    function _encodeAndCallProcessCreatePostOnFeed(
        address rule,
        bytes32 configSalt,
        uint256, /* rootPostId */
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IFeedRule.processCreatePost, (configSalt, postId, postParams, primitiveCustomParams, ruleCustomParams)
            )
        );
    }

    function _encodeAndCallProcessCreatePostOnRootPost(
        address rule,
        bytes32 configSalt,
        uint256 rootPostId,
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IPostRule.processCreatePost,
                (configSalt, rootPostId, postId, postParams, primitiveCustomParams, ruleCustomParams)
            )
        );
    }

    function _processPostCreation(
        function(address,bytes32,uint256,uint256,CreatePostParams calldata,KeyValue[] calldata,KeyValue[] memory) internal returns (bool, bytes memory)
            encodeAndCall,
        bytes4 ruleSelector,
        uint256 rootPostId,
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        RulesStorage storage _rulesStorage = rootPostId == 0 ? $feedRulesStorage() : $postRulesStorage(rootPostId);
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < _rulesStorage.requiredRules[ruleSelector].length; i++) {
            Rule memory rule = _rulesStorage.requiredRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.ruleAddress, rule.configSalt, rootPostId, postId, postParams, customParams, ruleCustomParams
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < _rulesStorage.anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = _rulesStorage.anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.ruleAddress, rule.configSalt, rootPostId, postId, postParams, customParams, ruleCustomParams
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require(_rulesStorage.anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }

    function _processPostCreationOnRootPost(
        uint256 rootPostId,
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata postRulesParams
    ) internal {
        _processPostCreation(
            _encodeAndCallProcessCreatePostOnRootPost,
            IPostRule.processCreatePost.selector,
            rootPostId,
            postId,
            postParams,
            customParams,
            postRulesParams
        );
    }

    function _processPostCreationOnFeed(
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams
    ) internal {
        _processPostCreation(
            _encodeAndCallProcessCreatePostOnFeed,
            IFeedRule.processCreatePost.selector,
            0,
            postId,
            postParams,
            customParams,
            feedRulesParams
        );
    }

    function _processPostEditingOnRootPost(
        uint256 rootPostId,
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata postRulesParams
    ) internal {
        _processPostEditing(
            _encodeAndCallProcessEditPostOnRootPost,
            IPostRule.processEditPost.selector,
            rootPostId,
            postId,
            postParams,
            customParams,
            postRulesParams
        );
    }

    function _processPostEditingOnFeed(
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams
    ) internal {
        _processPostEditing(
            _encodeAndCallProcessEditPostOnFeed,
            IFeedRule.processEditPost.selector,
            0,
            postId,
            postParams,
            customParams,
            feedRulesParams
        );
    }

    function _encodeAndCallProcessEditPostOnFeed(
        address rule,
        bytes32 configSalt,
        uint256, /* rootPostId */
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IFeedRule.processEditPost, (configSalt, postId, postParams, primitiveCustomParams, ruleCustomParams)
            )
        );
    }

    function _encodeAndCallProcessEditPostOnRootPost(
        address rule,
        bytes32 configSalt,
        uint256 rootPostId,
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IPostRule.processEditPost,
                (configSalt, rootPostId, postId, postParams, primitiveCustomParams, ruleCustomParams)
            )
        );
    }

    function _processPostEditing(
        function(address,bytes32,uint256,uint256,EditPostParams calldata,KeyValue[] calldata,KeyValue[] memory) internal returns (bool, bytes memory)
            encodeAndCall,
        bytes4 ruleSelector,
        uint256 rootPostId,
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        RulesStorage storage _rulesStorage = rootPostId == 0 ? $feedRulesStorage() : $postRulesStorage(rootPostId);
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < _rulesStorage.requiredRules[ruleSelector].length; i++) {
            Rule memory rule = _rulesStorage.requiredRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.ruleAddress, rule.configSalt, rootPostId, postId, postParams, customParams, ruleCustomParams
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < _rulesStorage.anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = _rulesStorage.anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.ruleAddress, rule.configSalt, rootPostId, postId, postParams, customParams, ruleCustomParams
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require(_rulesStorage.anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }

    function _processPostRemoval(
        uint256 postId,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        bytes4 ruleSelector = IFeedRule.processRemovePost.selector;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules[ruleSelector].length; i++) {
            Rule memory rule = $feedRulesStorage().requiredRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = rule.ruleAddress.call(
                    abi.encodeCall(
                        IFeedRule.processRemovePost, (rule.configSalt, postId, customParams, ruleCustomParams)
                    )
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = $feedRulesStorage().anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = rule.ruleAddress.call(
                    abi.encodeCall(
                        IFeedRule.processRemovePost, (rule.configSalt, postId, customParams, ruleCustomParams)
                    )
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($feedRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }

    function _processPostRulesChanges(
        uint256 postId,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        bytes4 ruleSelector = IFeedRule.processPostRuleChanges.selector;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules[ruleSelector].length; i++) {
            Rule memory rule = $feedRulesStorage().requiredRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = rule.ruleAddress.call(
                    abi.encodeCall(
                        IFeedRule.processPostRuleChanges, (rule.configSalt, postId, ruleChanges, ruleCustomParams)
                    )
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = $feedRulesStorage().anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.ruleAddress
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = rule.ruleAddress.call(
                    abi.encodeCall(
                        IFeedRule.processPostRuleChanges, (rule.configSalt, postId, ruleChanges, ruleCustomParams)
                    )
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($feedRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }
}
