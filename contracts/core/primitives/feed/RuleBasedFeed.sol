// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IPostRule} from "./../../interfaces/IPostRule.sol";
import {IFeedRule} from "./../../interfaces/IFeedRule.sol";
import {IFeed} from "./../../interfaces/IFeed.sol";
import {FeedCore as Core} from "./FeedCore.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {
    RuleChange,
    RuleProcessingParams,
    RuleConfigurationParams,
    Rule,
    RuleOperation,
    KeyValue
} from "./../../types/Types.sol";
import {EditPostParams, CreatePostParams} from "./../../interfaces/IFeed.sol";

abstract contract RuleBasedFeed is IFeed {
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

    // Public

    function changeFeedRules(RuleChange[] calldata ruleChanges) external override {
        _beforeChangeFeedRules(ruleChanges);
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleConfigurationParams memory ruleConfig = ruleChanges[i].configuration;
            if (ruleChanges[i].operation == RuleOperation.ADD) {
                _addFeedRule(ruleConfig);
                emit IFeed.Lens_Feed_RuleAdded(
                    ruleConfig.ruleAddress,
                    ruleConfig.configSalt,
                    ruleConfig.ruleSelector,
                    ruleConfig.customParams,
                    ruleConfig.isRequired
                );
            } else if (ruleChanges[i].operation == RuleOperation.UPDATE) {
                _updateFeedRule(ruleConfig);
                emit IFeed.Lens_Feed_RuleUpdated(
                    ruleConfig.ruleAddress,
                    ruleConfig.configSalt,
                    ruleConfig.ruleSelector,
                    ruleConfig.customParams,
                    ruleConfig.isRequired
                );
            } else {
                _removeFeedRule(ruleConfig);
                emit IFeed.Lens_Feed_RuleRemoved(ruleConfig.ruleAddress, ruleConfig.configSalt, ruleConfig.ruleSelector);
            }
        }
        require(
            $feedRulesStorage().anyOfRules[IFeedRule.processCreatePost.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $feedRulesStorage().anyOfRules[IFeedRule.processEditPost.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $feedRulesStorage().anyOfRules[IFeedRule.processPostRuleChanges.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
    }

    function changePostRules(
        uint256 postId,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] calldata feedRulesData
    ) external override {
        _beforeChangePostRules(postId, ruleChanges);
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        require(Core.$storage().posts[postId].rootPostId == postId, "ONLY_ROOT_POSTS_CAN_HAVE_RULES");
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleConfigurationParams memory ruleConfig = ruleChanges[i].configuration;
            if (ruleChanges[i].operation == RuleOperation.ADD) {
                _addFeedRule(ruleConfig);
                emit IFeed.Lens_Feed_Post_RuleAdded(
                    postId,
                    author,
                    ruleConfig.ruleAddress,
                    ruleConfig.configSalt,
                    ruleConfig.ruleSelector,
                    ruleConfig.customParams,
                    ruleConfig.isRequired
                );
            } else if (ruleChanges[i].operation == RuleOperation.UPDATE) {
                _updateFeedRule(ruleConfig);
                emit IFeed.Lens_Feed_Post_RuleUpdated(
                    postId,
                    author,
                    ruleConfig.ruleAddress,
                    ruleConfig.configSalt,
                    ruleConfig.ruleSelector,
                    ruleConfig.customParams,
                    ruleConfig.isRequired
                );
            } else {
                _removeFeedRule(ruleConfig);
                emit IFeed.Lens_Feed_Post_RuleRemoved(
                    postId, author, ruleConfig.ruleAddress, ruleConfig.configSalt, ruleConfig.ruleSelector
                );
            }
        }
        require(
            $postRulesStorage(postId).anyOfRules[IPostRule.processCreatePost.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $postRulesStorage(postId).anyOfRules[IPostRule.processEditPost.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        // Check the feed rules if it accepts the new RuleConfiguration
        _processPostRulesChanges(postId, ruleChanges, feedRulesData);
    }

    // Internal

    function _beforeChangeFeedRules(RuleChange[] calldata ruleChanges) internal virtual {}

    function _beforeChangePostRules(uint256 postId, RuleChange[] calldata ruleChanges) internal virtual {}

    function _addFeedRule(RuleConfigurationParams memory rule) internal {
        $feedRulesStorage().addRule(
            rule, abi.encodeCall(IFeedRule.configure, (rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _updateFeedRule(RuleConfigurationParams memory rule) internal {
        $feedRulesStorage().updateRule(
            rule, abi.encodeCall(IFeedRule.configure, (rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _removeFeedRule(RuleConfigurationParams memory rule) internal {
        $feedRulesStorage().removeRule(rule);
    }

    function _addPostRule(uint256 postId, RuleConfigurationParams memory rule) internal {
        $postRulesStorage(postId).addRule(
            rule, abi.encodeCall(IPostRule.configure, (postId, rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _updatePostRule(uint256 postId, RuleConfigurationParams memory rule) internal {
        $postRulesStorage(postId).updateRule(
            rule, abi.encodeCall(IPostRule.configure, (postId, rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _removePostRule(uint256 postId, RuleConfigurationParams memory rule) internal {
        $postRulesStorage(postId).removeRule(rule);
    }

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
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr, rule.configSalt, rootPostId, postId, postParams, customParams, ruleCustomParams
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
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted, bytes memory returnData) = encodeAndCall(
                    rule.addr, rule.configSalt, rootPostId, postId, postParams, customParams, ruleCustomParams
                );
                if (callNotReverted && abi.decode(returnData, (bool))) {
                    // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
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
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr, rule.configSalt, rootPostId, postId, postParams, customParams, ruleCustomParams
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
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted, bytes memory returnData) = encodeAndCall(
                    rule.addr, rule.configSalt, rootPostId, postId, postParams, customParams, ruleCustomParams
                );
                if (callNotReverted && abi.decode(returnData, (bool))) {
                    // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
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
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = rule.addr.call(
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
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted, bytes memory returnData) = rule.addr.call(
                    abi.encodeCall(
                        IFeedRule.processRemovePost, (rule.configSalt, postId, customParams, ruleCustomParams)
                    )
                );
                if (callNotReverted && abi.decode(returnData, (bool))) {
                    // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($feedRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }

    function _processPostRulesChanges(
        uint256 postId,
        RuleChange[] memory ruleChanges,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        bytes4 ruleSelector = IFeedRule.processPostRuleChanges.selector;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules[ruleSelector].length; i++) {
            Rule memory rule = $feedRulesStorage().requiredRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = rule.addr.call(
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
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted, bytes memory returnData) = rule.addr.call(
                    abi.encodeCall(
                        IFeedRule.processPostRuleChanges, (rule.configSalt, postId, ruleChanges, ruleCustomParams)
                    )
                );
                if (callNotReverted && abi.decode(returnData, (bool))) {
                    // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($feedRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }

    function getFeedRules(bytes4 ruleSelector, bool isRequired) external view returns (Rule[] memory) {
        return $feedRulesStorage()._getRulesArray(ruleSelector, isRequired);
    }

    function getPostRules(bytes4 ruleSelector, uint256 postId, bool isRequired) external view returns (Rule[] memory) {
        return $postRulesStorage(postId)._getRulesArray(ruleSelector, isRequired);
    }
}
