// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IPostRule} from "./../../core/interfaces/IPostRule.sol";
import {IGraph} from "./../../core/interfaces/IGraph.sol";
import {IFeed} from "./../../core/interfaces/IFeed.sol";
import {KeyValue} from "./../../core/types/Types.sol";
import {CreatePostParams, EditPostParams} from "./../../core/interfaces/IFeed.sol";

contract FollowersOnlyPostRule is IPostRule {
    struct Configuration {
        address graph;
        bool repliesRestricted;
        bool repostsRestricted;
        bool quotesRestricted;
    }

    // keccak256("lens.param.key.graph");
    bytes32 immutable GRAPH_PARAM_KEY = 0x628a4bca9db11e5f912854a55e24d0941ed8a7ef363805062e4742b80ebd87d3;
    // keccak256("lens.param.key.repliesRestricted");
    bytes32 immutable REPLIES_RESTRICTED_PARAM_KEY = 0x95bbd2e4311bcbf9c65ad79e6a70b63a8d50c9d6a0f746285b582b19d9c60cab;
    // keccak256("lens.param.key.repostsRestricted");
    bytes32 immutable REPOSTS_RESTRICTED_PARAM_KEY = 0x7be144f8221b98a59a886bdac9502f9e8311a283b170b902fa01d25cf68b9bb9;
    // keccak256("lens.param.key.quotesRestricted");
    bytes32 immutable QUOTES_RESTRICTED_PARAM_KEY = 0xaa67cc93791051d4b576cfc397a1494d5f4baf59f14681843bfef453034cd9fa;

    mapping(address => mapping(uint256 => mapping(bytes4 => mapping(bytes32 => Configuration)))) internal _configuration;

    function configure(
        uint256 postId,
        bytes4 ruleSelector,
        bytes32 salt,
        KeyValue[] calldata ruleConfigurationParams
    ) external override {
        require(ruleSelector == this.processCreatePost.selector);
        Configuration memory configuration;
        for (uint256 i = 0; i < ruleConfigurationParams.length; i++) {
            if (ruleConfigurationParams[i].key == GRAPH_PARAM_KEY) {
                configuration.graph = abi.decode(ruleConfigurationParams[i].value, (address));
            } else if (ruleConfigurationParams[i].key == REPLIES_RESTRICTED_PARAM_KEY) {
                configuration.repliesRestricted = abi.decode(ruleConfigurationParams[i].value, (bool));
            } else if (ruleConfigurationParams[i].key == REPOSTS_RESTRICTED_PARAM_KEY) {
                configuration.repostsRestricted = abi.decode(ruleConfigurationParams[i].value, (bool));
            } else if (ruleConfigurationParams[i].key == QUOTES_RESTRICTED_PARAM_KEY) {
                configuration.quotesRestricted = abi.decode(ruleConfigurationParams[i].value, (bool));
            }
        }
        IGraph(configuration.graph).getFollowersCount(address(this)); // Aims to verify the given address is a IGraph
        require(configuration.repliesRestricted || configuration.repostsRestricted || configuration.quotesRestricted);
        _configuration[msg.sender][postId][ruleSelector][salt] = configuration;
    }

    function processCreatePost(
        bytes32 configSalt,
        uint256 rootPostId,
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external view override {
        Configuration memory configuration =
            _configuration[msg.sender][rootPostId][this.processCreatePost.selector][configSalt];
        if (_shouldRestrictionBeApplied(configuration, rootPostId, postParams)) {
            IFeed feed = IFeed(msg.sender);
            IGraph graph = IGraph(configuration.graph);
            address rootPostAuthor = feed.getPostAuthor(rootPostId);
            address newPostAuthor = feed.getPostAuthor(postId);
            require(graph.isFollowing({followerAccount: newPostAuthor, targetAccount: rootPostAuthor}));
        }
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* rootPostId */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override {
        revert();
    }

    // TODO: This function smells weird, we should reconsider going back to the processQuote/Reply/Repost selectors...
    function _shouldRestrictionBeApplied(
        Configuration memory configuration,
        uint256 rootPostId,
        CreatePostParams calldata postParams
    ) internal view returns (bool) {
        IFeed feed = IFeed(msg.sender);
        if (configuration.repliesRestricted && postParams.repliedPostId != 0) {
            uint256 repliedPostRootId = feed.getPost(postParams.repliedPostId).rootPostId;
            if (repliedPostRootId == rootPostId) {
                return true;
            }
        }
        if (configuration.repostsRestricted && postParams.repostedPostId != 0) {
            uint256 repostedPostRootId = feed.getPost(postParams.repostedPostId).rootPostId;
            if (repostedPostRootId == rootPostId) {
                return true;
            }
        }
        if (configuration.quotesRestricted && postParams.quotedPostId != 0) {
            uint256 quotedPostRootId = feed.getPost(postParams.quotedPostId).rootPostId;
            if (quotedPostRootId == rootPostId) {
                return true;
            }
        }
        return false;
    }
}
