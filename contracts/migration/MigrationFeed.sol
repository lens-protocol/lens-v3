// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue, RuleProcessingParams} from "contracts/core/types/Types.sol";
import {CreatePostParams} from "contracts/core/interfaces/IFeed.sol";
import {FeedCore as Core, PostStorage} from "contracts/core/primitives/feed/FeedCore.sol";
import {Feed} from "contracts/core/primitives/feed/Feed.sol";

struct PostCreationParams {
    uint256 postId;
    uint256 rootPostId;
    uint256 postSequentialId;
    uint256 authorPostSequentialId;
    uint80 creationTimestamp;
    address source;
}

contract MigrationFeed is Feed {
    function createPost(
        CreatePostParams memory postParams,
        KeyValue[] memory customParams,
        RuleProcessingParams[] memory feedRulesParams,
        RuleProcessingParams[] memory rootPostRulesParams,
        RuleProcessingParams[] memory quotedPostRulesParams
    ) external override returns (uint256) {
        PostCreationParams memory postCreationParams = abi.decode(customParams[0].value, (PostCreationParams));
        _createPost(
            postParams,
            postCreationParams.postId,
            postCreationParams.rootPostId,
            postCreationParams.postSequentialId,
            postCreationParams.authorPostSequentialId,
            postCreationParams.creationTimestamp
        );

        if (customParams.length > 1 && abi.decode(customParams[1].value, (bool))) {
            // If customParams[1] is present, it must be an ABI-encoded bool representing `forceChecks`
            _forceChecks(postCreationParams.postId, postCreationParams.rootPostId, postParams);
        }

        if (postCreationParams.source != address(0)) {
            // Trust the migrator, no source verification
            _setPrimitiveInternalExtraDataForEntity(
                postCreationParams.postId, KeyValue(DATA__SOURCE, abi.encode(postCreationParams.source))
            );
            _setPrimitiveInternalExtraDataForEntity(
                postCreationParams.postId, KeyValue(DATA__LAST_UPDATED_SOURCE, abi.encode(postCreationParams.source))
            );
        }

        emit Lens_Feed_PostCreated(
            postCreationParams.postId,
            postParams.author,
            postCreationParams.authorPostSequentialId,
            postCreationParams.rootPostId,
            postParams,
            customParams,
            feedRulesParams,
            rootPostRulesParams,
            quotedPostRulesParams,
            postCreationParams.source
        );

        for (uint256 i = 0; i < postParams.extraData.length; i++) {
            _setEntityExtraData(postCreationParams.postId, postParams.extraData[i]);
            emit Lens_Feed_Post_ExtraDataAdded(
                postCreationParams.postId,
                postParams.extraData[i].key,
                postParams.extraData[i].value,
                postParams.extraData[i].value
            );
        }
        return postCreationParams.postId;
    }

    // Overriding the FeedCore
    function _createPost(
        CreatePostParams memory postParams,
        uint256 postId,
        uint256 rootPostId,
        uint256 postSequentialId,
        uint256 authorPostSequentialId,
        uint80 creationTimestamp
    ) internal {
        Core.$storage().postCount = postSequentialId;
        Core.$storage().authorPostCount[postParams.author] = authorPostSequentialId;
        PostStorage storage _newPost = Core.$storage().posts[postId];
        _newPost.author = postParams.author;
        _newPost.authorPostSequentialId = authorPostSequentialId;
        _newPost.postSequentialId = postSequentialId;
        _newPost.contentURI = postParams.contentURI;
        _newPost.quotedPostId = postParams.quotedPostId;
        _newPost.repliedPostId = postParams.repliedPostId;
        _newPost.repostedPostId = postParams.repostedPostId;
        _newPost.rootPostId = rootPostId;
        _newPost.creationTimestamp = creationTimestamp;
        _newPost.lastUpdatedTimestamp = creationTimestamp;
    }

    function _forceChecks(uint256 postId, uint256 rootPostId, CreatePostParams memory postParams) internal view {
        // TODO: Check if the rootPostId == postId case (not a reply, not a repost)
        if (rootPostId != postId) {
            require(Core._postExists(rootPostId));
        }
        if (postParams.quotedPostId != 0) {
            require(Core._postExists(postParams.quotedPostId));
        }
        if (postParams.repliedPostId != 0) {
            require(Core._postExists(postParams.repliedPostId));
            require(rootPostId == Core.$storage().posts[postParams.repliedPostId].rootPostId);
        }
        if (postParams.repostedPostId != 0) {
            require(Core._postExists(postParams.repostedPostId));
            require(postParams.quotedPostId == 0 && postParams.repliedPostId == 0);
            require(rootPostId == Core.$storage().posts[postParams.repostedPostId].rootPostId);
            require(bytes(postParams.contentURI).length == 0, "REPOST_CANNOT_HAVE_CONTENT");
        }
    }
}
