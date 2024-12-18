// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {IFeedRule} from "./../../core/interfaces/IFeedRule.sol";
import {IGraphRule} from "./../../core/interfaces/IGraphRule.sol";
import {CreatePostParams, EditPostParams} from "./../../core/interfaces/IFeed.sol";
import {KeyValue, RuleConfigurationChange, RuleSelectorChange} from "./../../core/types/Types.sol";
import {IFeed} from "./../../core/interfaces/IFeed.sol";

contract UserBlockingRule is IFeedRule, IGraphRule {
    event Lens_UserBlocking_UserBlocked(address indexed source, address indexed target, uint256 timestamp);
    event Lens_UserBlocking_UserUnblocked(address indexed source, address indexed target);

    mapping(address => mapping(address => uint256)) public userBlocks;

    function configure(
        bytes32, /* salt */
        KeyValue[] calldata /* ruleConfigurationParams */
    ) external pure override(IFeedRule, IGraphRule) {}

    function blockUser(address source, address target) external {
        require(msg.sender == source, "Only the source can block a user");
        require(source != target, "Cannot block self");
        userBlocks[source][target] = block.timestamp;
    }

    function unblockUser(address source, address target) external {
        require(msg.sender == source, "Only the source can unblock a user");
        userBlocks[msg.sender][target] = 0;
    }

    function processCreatePost(
        bytes32, /* configSalt */
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external view {
        if (postParams.repliedPostId != 0) {
            address author = postParams.author;
            address repliedToAuthor = IFeed(msg.sender).getPostAuthor(postParams.repliedPostId);
            uint256 rootPostId = IFeed(msg.sender).getPost(postId).rootPostId;
            address rootAuthor = IFeed(msg.sender).getPostAuthor(rootPostId);
            if (_isBlocked({source: repliedToAuthor, blockTarget: author})) {
                revert("User is blocked from replying to this user");
            }
            if (_isBlocked({source: rootAuthor, blockTarget: author})) {
                revert("User is blocked from commenting on this author's posts");
            }
        }
    }

    function processFollow(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external view {
        if (_isBlocked({source: accountToFollow, blockTarget: followerAccount})) {
            revert("User is blocked from following this user");
        }
    }

    function isBlocked(address source, address blockTarget) external view returns (bool) {
        return _isBlocked(source, blockTarget);
    }

    function _isBlocked(address source, address blockTarget) internal view returns (bool) {
        return userBlocks[source][blockTarget] > 0;
    }

    // Unimplemented functions

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure {
        revert();
    }

    function processRemovePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure {
        revert();
    }

    function processPostRuleChanges(
        bytes32, /* configSalt */
        uint256, /* postId */
        RuleConfigurationChange[] calldata, /* configChanges */
        RuleSelectorChange[] calldata, /* selectorChanges */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure {
        revert();
    }

    function processUnfollow(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* followerAccount */
        address, /* accountToUnfollow */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure {
        revert();
    }

    function processFollowRuleChanges(
        bytes32, /* configSalt */
        address, /* account */
        RuleConfigurationChange[] calldata, /* configChanges */
        RuleSelectorChange[] calldata, /* selectorChanges */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure {
        revert();
    }
}
