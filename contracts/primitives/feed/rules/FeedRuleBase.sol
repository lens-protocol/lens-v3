// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IFeedRule} from "./../IFeedRule.sol";
import {CreatePostParams, EditPostParams, Post, IFeed} from "./../IFeed.sol";
import {RuleConfiguration} from "./../../../types/Types.sol";

enum FeedAction {
    CreatePost,
    EditPost,
    DeletePost,
    PostRulesChanged
}

enum PostType {
    Post,
    Reply,
    Quote,
    ReplyWithQuote,
    Repost
}

struct FeedRuleConfig {
    FeedAction feedAction;
    PostType postType;
    bytes configData;
}

contract FeedRuleBase is IFeedRule {
    // TODO: Consider moving this down to implementation
    mapping(address feed => mapping(FeedAction feedAction => mapping(PostType postType => bytes configData))) internal
        _feedRuleConfigs;

    function configure(bytes calldata data) external override {
        _configure(data);
    }

    function processCreatePost(
        uint256 postId,
        uint256 localSequentialId,
        CreatePostParams calldata postParams,
        bytes calldata data
    ) external override returns (bool) {
        PostType postType = _getPostType(postId);
        bytes memory config = _feedRuleConfigs[msg.sender][FeedAction.CreatePost][postType];
        return _processCreatePost(config, postId, localSequentialId, postParams, data);
    }

    function processEditPost(
        uint256 postId,
        uint256 localSequentialId,
        EditPostParams calldata editPostParams,
        bytes calldata data
    ) external override returns (bool) {
        PostType postType = _getPostType(postId);
        bytes memory config = _feedRuleConfigs[msg.sender][FeedAction.EditPost][postType];
        return _processEditPost(config, postId, localSequentialId, editPostParams, data);
    }

    function processDeletePost(uint256 postId, uint256 localSequentialId, bytes calldata data)
        external
        override
        returns (bool)
    {
        PostType postType = _getPostType(postId);
        bytes memory config = _feedRuleConfigs[msg.sender][FeedAction.DeletePost][postType];
        return _processDeletePost(config, postId, localSequentialId, data);
    }

    function processPostRulesChanged(
        uint256 postId,
        uint256 localSequentialId,
        RuleConfiguration[] calldata newPostRules,
        bytes calldata data
    ) external override returns (bool) {
        PostType postType = _getPostType(postId);
        bytes memory config = _feedRuleConfigs[msg.sender][FeedAction.PostRulesChanged][postType];
        return _processPostRulesChanged(config, postId, localSequentialId, newPostRules, data);
    }

    function _configure(bytes calldata data) internal virtual {
        (FeedRuleConfig[] memory configs) = abi.decode(data, (FeedRuleConfig[]));
        for (uint256 i = 0; i < configs.length; i++) {
            FeedRuleConfig memory config = configs[i];
            _configureFeedRule(config);
        }
    }

    function _configureFeedRule(FeedRuleConfig memory config) internal virtual {
        _feedRuleConfigs[msg.sender][config.feedAction][config.postType] = config.configData;
    }

    function _processCreatePost(
        bytes memory, /* config */
        uint256, /* postId */
        uint256, /* localSequentialId */
        CreatePostParams calldata, /* postParams */
        bytes calldata /* data */
    ) internal virtual returns (bool implemented) {
        return false;
    }

    function _processEditPost(
        bytes memory, /* config */
        uint256, /* postId */
        uint256, /* localSequentialId */
        EditPostParams calldata, /* editPostParams */
        bytes calldata /* data */
    ) internal virtual returns (bool implemented) {
        return false;
    }

    function _processDeletePost(
        bytes memory, /* config */
        uint256, /* postId */
        uint256, /* localSequentialId */
        bytes calldata /* data */
    ) internal virtual returns (bool implemented) {
        return false;
    }

    function _processPostRulesChanged(
        bytes memory, /* config */
        uint256, /* postId */
        uint256, /* localSequentialId */
        RuleConfiguration[] calldata, /* newPostRules */
        bytes calldata /* data */
    ) internal virtual returns (bool implemented) {
        return false;
    }

    function _getPostType(uint256 postId) internal virtual returns (PostType) {
        // TODO: Think if we can optimize this not fetching everything from storage
        Post memory postParams = IFeed(msg.sender).getPost(postId);
        uint256 rootPostId = postParams.rootPostId;

        if (rootPostId == postId) {
            if (postParams.quotedPostId == 0) {
                // Post is a simple root post (not a quote, reply or repost)
                return PostType.Post;
            } else {
                // Post is a quote
                return PostType.Quote;
            }
        } else {
            // Post is either a repost or a reply
            if (postParams.repostedPostId > 0) {
                // Post is a repost
                return PostType.Repost;
            } else {
                // Post is a reply (with or without a quote)
                if (postParams.quotedPostId > 0) {
                    // Post is a reply with a quote
                    return PostType.ReplyWithQuote;
                } else {
                    // Post is a simple reply
                    return PostType.Reply;
                }
            }
        }
    }
}
