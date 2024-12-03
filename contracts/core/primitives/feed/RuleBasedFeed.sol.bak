// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IPostRule} from "./../../interfaces/IPostRule.sol";
import {IFeedRule} from "./../../interfaces/IFeedRule.sol";
import {FeedCore as Core} from "./FeedCore.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {RuleConfiguration, RuleChange, RuleExecutionData} from "./../../types/Types.sol";
import {EditPostParams, CreatePostParams} from "./../../interfaces/IFeed.sol";

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

    function _addFeedRule(RuleConfiguration memory rule) internal {
        $feedRulesStorage().addRule(rule, abi.encodeCall(IFeedRule.configure, (rule.configData)));
    }

    function _updateFeedRule(RuleConfiguration memory rule) internal {
        $feedRulesStorage().updateRule(rule, abi.encodeCall(IFeedRule.configure, (rule.configData)));
    }

    function _removeFeedRule(address rule) internal {
        $feedRulesStorage().removeRule(rule);
    }

    function _addPostRule(uint256 postId, RuleConfiguration memory rule) internal {
        $postRulesStorage(postId).addRule(rule, abi.encodeCall(IPostRule.configure, (postId, rule.configData)));
    }

    function _updatePostRule(uint256 postId, RuleConfiguration memory rule) internal {
        $postRulesStorage(postId).updateRule(rule, abi.encodeCall(IPostRule.configure, (postId, rule.configData)));
    }

    function _removePostRule(uint256 postId, address rule) internal {
        $postRulesStorage(postId).removeRule(rule);
    }

    function _processQuotedPostRules(
        uint256 quotedPostId,
        uint256 postId,
        RuleExecutionData calldata quotedPostRulesData
    ) internal {
        uint256 rootPostId = Core.$storage().posts[quotedPostId].rootPostId;
        RulesStorage storage rulesToProcess = $postRulesStorage(rootPostId);

        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < rulesToProcess.requiredRules.length; i++) {
            (bool callNotReverted,) = rulesToProcess.requiredRules[i].call(
                abi.encodeCall(
                    IPostRule.processQuote,
                    (rootPostId, quotedPostId, postId, quotedPostRulesData.dataForRequiredRules[i])
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if (rulesToProcess.anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < rulesToProcess.anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = rulesToProcess.anyOfRules[i].call(
                abi.encodeCall(
                    IPostRule.processQuote, (rootPostId, quotedPostId, postId, quotedPostRulesData.dataForAnyOfRules[i])
                )
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _processRepliedPostRules(
        uint256 repliedPostId,
        uint256 postId,
        RuleExecutionData calldata parentPostRulesData
    ) internal {
        uint256 rootPostId = Core.$storage().posts[repliedPostId].rootPostId;
        RulesStorage storage rulesToProcess = $postRulesStorage(rootPostId);

        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < rulesToProcess.requiredRules.length; i++) {
            (bool callNotReverted,) = rulesToProcess.requiredRules[i].call(
                abi.encodeCall(
                    IPostRule.processReply,
                    (rootPostId, repliedPostId, postId, parentPostRulesData.dataForRequiredRules[i])
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if (rulesToProcess.anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < rulesToProcess.anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = rulesToProcess.anyOfRules[i].call(
                abi.encodeCall(
                    IPostRule.processReply, (rootPostId, repliedPostId, postId, parentPostRulesData.dataForAnyOfRules[i])
                )
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _processRepostedPostRules(
        uint256 repostedPostId,
        uint256 postId,
        RuleExecutionData calldata parentPostRulesData
    ) internal {
        uint256 rootPostId = Core.$storage().posts[repostedPostId].rootPostId;
        RulesStorage storage rulesToProcess = $postRulesStorage(rootPostId);

        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < rulesToProcess.requiredRules.length; i++) {
            (bool callNotReverted,) = rulesToProcess.requiredRules[i].call(
                abi.encodeCall(
                    IPostRule.processRepost,
                    (rootPostId, repostedPostId, postId, parentPostRulesData.dataForRequiredRules[i])
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if (rulesToProcess.anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < rulesToProcess.anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = rulesToProcess.anyOfRules[i].call(
                abi.encodeCall(
                    IPostRule.processRepost,
                    (rootPostId, repostedPostId, postId, parentPostRulesData.dataForAnyOfRules[i])
                )
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _processPostCreation(uint256 postId, CreatePostParams calldata postParams) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $feedRulesStorage().requiredRules[i].call(
                abi.encodeCall(
                    IFeedRule.processCreatePost, (postId, postParams, postParams.feedRulesData.dataForRequiredRules[i])
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
                abi.encodeCall(
                    IFeedRule.processCreatePost, (postId, postParams, postParams.feedRulesData.dataForAnyOfRules[i])
                )
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
                abi.encodeCall(IFeedRule.processEditPost, (postId, newPostParams, feedRulesData.dataForRequiredRules[i]))
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($feedRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $feedRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $feedRulesStorage().anyOfRules[i].call(
                abi.encodeCall(IFeedRule.processEditPost, (postId, newPostParams, feedRulesData.dataForAnyOfRules[i]))
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the OR rules failed");
    }

    function _processChangesOnPostRules(
        uint256 postId,
        RuleChange[] memory ruleChanges,
        RuleExecutionData calldata feedRulesData
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $feedRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $feedRulesStorage().requiredRules[i].call(
                abi.encodeCall(
                    IFeedRule.processPostRuleChanges, (postId, ruleChanges, feedRulesData.dataForRequiredRules[i])
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
                abi.encodeCall(
                    IFeedRule.processPostRuleChanges, (postId, ruleChanges, feedRulesData.dataForAnyOfRules[i])
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
