// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IPostRule} from "./../../core/interfaces/IPostRule.sol";
import {IGraph} from "./../../core/interfaces/IGraph.sol";
import {IFeed} from "./../../core/interfaces/IFeed.sol";

contract FollowersOnlyPostRule is IPostRule {
    struct Configuration {
        address graph;
        bool repliesRestricted;
        bool repostsRestricted;
        bool quotesRestricted;
    }

    mapping(address => mapping(uint256 => Configuration)) internal _configuration;

    function configure(uint256 postId, bytes calldata data) external override {
        Configuration memory configuration = abi.decode(data, (Configuration));
        _configuration[msg.sender][postId] = configuration;
    }

    function processQuote(
        uint256 rootPostId,
        uint256, /* quotedPostId */
        uint256 postId,
        bytes calldata /* data */
    ) external view override returns (bool) {
        return _processRestriction({
            isRestrictionEnabled: _configuration[msg.sender][rootPostId].quotesRestricted,
            feed: msg.sender,
            graph: _configuration[msg.sender][rootPostId].graph,
            rootPostId: rootPostId,
            newPostId: postId
        });
    }

    function processReply(
        uint256 rootPostId,
        uint256, /* repliedPostId */
        uint256 postId,
        bytes calldata /* data */
    ) external view override returns (bool) {
        return _processRestriction({
            isRestrictionEnabled: _configuration[msg.sender][rootPostId].repliesRestricted,
            feed: msg.sender,
            graph: _configuration[msg.sender][rootPostId].graph,
            rootPostId: rootPostId,
            newPostId: postId
        });
    }

    function processRepost(
        uint256 rootPostId,
        uint256, /* repostedPostId */
        uint256 postId,
        bytes calldata /* data */
    ) external view override returns (bool) {
        return _processRestriction({
            isRestrictionEnabled: _configuration[msg.sender][rootPostId].repostsRestricted,
            feed: msg.sender,
            graph: _configuration[msg.sender][rootPostId].graph,
            rootPostId: rootPostId,
            newPostId: postId
        });
    }

    function _processRestriction(
        bool isRestrictionEnabled,
        address feed,
        address graph,
        uint256 rootPostId,
        uint256 newPostId
    ) internal view returns (bool) {
        if (isRestrictionEnabled) {
            address rootPostAuthor = IFeed(feed).getPostAuthor(rootPostId);
            address newPostAuthor = IFeed(feed).getPostAuthor(newPostId);
            require(IGraph(graph).isFollowing({followerAccount: newPostAuthor, targetAccount: rootPostAuthor}));
        }
        return isRestrictionEnabled;
    }
}
