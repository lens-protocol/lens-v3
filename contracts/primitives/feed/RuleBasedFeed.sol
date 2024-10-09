// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPostRule} from "./IPostRule.sol";
import {IFeedRule} from "./IFeedRule.sol";
import {FeedCore as Core} from "./FeedCore.sol";
import {RulesStorage, RulesLib} from "./../base/RulesLib.sol";
import {RuleConfiguration, RuleExecutionData} from "./../../types/Types.sol";
import {EditPostParams, CreatePostParams, CreateRepostParams} from "./IFeed.sol";

contract RuleBasedFeed {
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

    // Internal

    function _addFeedRule(RuleConfiguration calldata rule) internal {
        $feedRulesStorage().addRule(rule, abi.encodeWithSelector(IFeedRule.configure.selector, rule.configData));
    }

    function _updateFeedRule(RuleConfiguration calldata rule) internal {
        $feedRulesStorage().updateRule(rule, abi.encodeWithSelector(IFeedRule.configure.selector, rule.configData));
    }

    function _removeFeedRule(address rule) internal {
        $feedRulesStorage().removeRule(rule);
    }

    function _addPostRule(uint256 postId, RuleConfiguration calldata rule) internal {
        $postRulesStorage(postId).addRule(
            rule, abi.encodeWithSelector(IPostRule.configure.selector, postId, rule.configData)
        );
    }

    function _updatePostRule(uint256 postId, RuleConfiguration calldata rule) internal {
        $postRulesStorage(postId).updateRule(
            rule, abi.encodeWithSelector(IPostRule.configure.selector, postId, rule.configData)
        );
    }

    function _removePostRule(uint256 postId, address rule) internal {
        $postRulesStorage(postId).removeRule(rule);
    }

    function _processAllParentsPostsRules(
        uint256 parentPostId,
        uint256 childPostId,
        RuleExecutionData calldata parentPostRulesData
    ) internal {
        _postProcessParent(parentPostId, childPostId, parentPostRulesData);
    }

    function _processAllParentsAndQuotedPostsRules(
        uint256 quotedPostId,
        uint256 parentPostId,
        uint256 childPostId,
        RuleExecutionData calldata quotedPostRulesData,
        RuleExecutionData calldata parentPostRulesData
    ) internal {
        _postProcessQuote(quotedPostId, childPostId, quotedPostRulesData);
        _postProcessParent(parentPostId, childPostId, parentPostRulesData);
    }

    function _postProcessQuote(
        uint256 quotedPostId,
        uint256 childPostId,
        RuleExecutionData calldata quotedPostRulesData
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $postRulesStorage(quotedPostId).requiredRules.length; i++) {
            (bool callNotReverted,) = $postRulesStorage(quotedPostId).requiredRules[i].call(
                abi.encodeWithSelector(
                    IPostRule.processQuote.selector,
                    quotedPostId,
                    childPostId,
                    quotedPostRulesData.dataForRequiredRules[i]
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($postRulesStorage(quotedPostId).anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $postRulesStorage(quotedPostId).anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $postRulesStorage(quotedPostId).anyOfRules[i].call(
                abi.encodeWithSelector(
                    IPostRule.processQuote.selector, quotedPostId, childPostId, quotedPostRulesData.dataForAnyOfRules[i]
                )
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _postProcessParent(
        uint256 parentPostId,
        uint256 childPostId,
        RuleExecutionData calldata parentPostRulesData
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $postRulesStorage(parentPostId).requiredRules.length; i++) {
            (bool callNotReverted,) = $postRulesStorage(parentPostId).requiredRules[i].call(
                abi.encodeWithSelector(
                    IPostRule.processParent.selector,
                    parentPostId,
                    childPostId,
                    parentPostRulesData.dataForRequiredRules[i]
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($postRulesStorage(parentPostId).anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $postRulesStorage(parentPostId).anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $postRulesStorage(parentPostId).anyOfRules[i].call(
                abi.encodeWithSelector(
                    IPostRule.processParent.selector,
                    parentPostId,
                    childPostId,
                    parentPostRulesData.dataForAnyOfRules[i]
                )
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _feedProcessCreatePost(uint256 postId, uint256 localSequentialId, CreatePostParams calldata postParams)
        internal
    {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $feedRulesStorage().requiredRules[i].call(
                abi.encodeWithSelector(IFeedRule.processCreatePost.selector, postId, localSequentialId, postParams)
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($feedRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $feedRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $feedRulesStorage().anyOfRules[i].call(
                abi.encodeWithSelector(IFeedRule.processCreatePost.selector, postId, localSequentialId, postParams)
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _feedProcessCreateRepost(
        uint256 postId,
        uint256 localSequentialId,
        CreateRepostParams calldata repostParams
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $feedRulesStorage().requiredRules[i].call(
                abi.encodeWithSelector(IFeedRule.processCreatePost.selector, postId, localSequentialId, repostParams)
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($feedRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $feedRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $feedRulesStorage().anyOfRules[i].call(
                abi.encodeWithSelector(IFeedRule.processCreatePost.selector, postId, localSequentialId, repostParams)
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _feedProcessEditPost(
        uint256 postId,
        EditPostParams calldata newPostParams,
        RuleExecutionData calldata feedRulesData
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $feedRulesStorage().requiredRules[i].call(
                abi.encodeWithSelector(
                    IFeedRule.processEditPost.selector, postId, newPostParams, feedRulesData.dataForRequiredRules[i]
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($feedRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $feedRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $feedRulesStorage().anyOfRules[i].call(
                abi.encodeWithSelector(
                    IFeedRule.processEditPost.selector, postId, newPostParams, feedRulesData.dataForAnyOfRules[i]
                )
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _processAllParentsRulesChildPostRulesChanged(
        uint256 postId,
        RuleConfiguration[] calldata childRules,
        RuleExecutionData calldata quotePostRulesData,
        RuleExecutionData calldata parentPostRulesData
    ) internal {
        _processChildPostRulesChanged(
            Core.$storage().posts[postId].quotedPostId, postId, childRules, quotePostRulesData
        );
        _processChildPostRulesChanged(
            Core.$storage().posts[postId].parentPostId, postId, childRules, parentPostRulesData
        );
    }

    function _processChildPostRulesChanged(
        uint256 parentPostId,
        uint256 childPostId,
        RuleConfiguration[] calldata newChildPostRulesData,
        RuleExecutionData calldata parentPostRulesData
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $postRulesStorage(parentPostId).requiredRules.length; i++) {
            (bool callNotReverted,) = $postRulesStorage(parentPostId).requiredRules[i].call(
                abi.encodeWithSelector(
                    IPostRule.processChildPostRulesChanged.selector,
                    parentPostId,
                    childPostId,
                    newChildPostRulesData,
                    parentPostRulesData.dataForRequiredRules[i]
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($postRulesStorage(parentPostId).anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $postRulesStorage(parentPostId).anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $postRulesStorage(parentPostId).anyOfRules[i].call(
                abi.encodeWithSelector(
                    IPostRule.processChildPostRulesChanged.selector,
                    parentPostId,
                    childPostId,
                    newChildPostRulesData,
                    parentPostRulesData.dataForAnyOfRules[i]
                )
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _feedProcessDeletePost(uint256 postId, RuleExecutionData calldata feedRulesData) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $feedRulesStorage().requiredRules[i].call(
                abi.encodeWithSelector(
                    IFeedRule.processDeletePost.selector, postId, feedRulesData.dataForRequiredRules[i]
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($feedRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $feedRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $feedRulesStorage().anyOfRules[i].call(
                abi.encodeWithSelector(IFeedRule.processDeletePost.selector, postId, feedRulesData.dataForAnyOfRules[i])
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _feedProcessPostRulesChanged(
        address author,
        uint256 postId,
        RuleConfiguration[] calldata newPostRules,
        RuleExecutionData calldata feedRulesData
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $feedRulesStorage().requiredRules[i].call(
                abi.encodeWithSelector(
                    IFeedRule.processPostRulesChanged.selector,
                    author,
                    postId,
                    newPostRules,
                    feedRulesData.dataForRequiredRules[i]
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($feedRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $feedRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $feedRulesStorage().anyOfRules[i].call(
                abi.encodeWithSelector(
                    IFeedRule.processPostRulesChanged.selector,
                    author,
                    postId,
                    newPostRules,
                    feedRulesData.dataForAnyOfRules[i]
                )
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _getFeedRules(bool isRequired) internal view returns (address[] memory) {
        return $feedRulesStorage().getRulesArray(isRequired);
    }

    function _getPostRules(uint256 postId, bool isRequired) internal view returns (address[] memory) {
        return $postRulesStorage(postId).getRulesArray(isRequired);
    }
}
