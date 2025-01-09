// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue, RuleProcessingParams} from "contracts/core/types/Types.sol";
import {CreatePostParams} from "contracts/core/interfaces/IFeed.sol";
import {FeedCore as Core, PostStorage} from "contracts/core/primitives/feed/FeedCore.sol";
import {Feed} from "contracts/core/primitives/feed/Feed.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract MigrationFeed is Feed {
    function createPost(
        CreatePostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams,
        RuleProcessingParams[] calldata rootPostRulesParams,
        RuleProcessingParams[] calldata quotedPostRulesParams
    ) external override returns (uint256) {
        (
            uint256 postId,
            uint256 rootPostId,
            uint256 postSequentialId,
            uint256 authorPostSequentialId,
            uint80 creationTimestamp,
            address source
        ) = abi.decode(customParams[0].value, (uint256, uint256, uint256, uint256, uint80, address));
        _createPost(postParams, postId, rootPostId, postSequentialId, authorPostSequentialId, creationTimestamp);

        if (customParams.length > 1 && abi.decode(customParams[1].value, (bool))) {
            // If customParams[1] is present, it must be an ABI-encoded bool representing `forceChecks`
            _forceChecks(postId, rootPostId, postParams);
        }

        if (source != address(0)) {
            // Trust the migrator, no source verification
            _setPrimitiveInternalExtraDataForEntity(postId, KeyValue(DATA__SOURCE, abi.encode(source)));
            _setPrimitiveInternalExtraDataForEntity(postId, KeyValue(DATA__LAST_UPDATED_SOURCE, abi.encode(source)));
        }

        emit Lens_Feed_PostCreated(
            postId,
            postParams.author,
            authorPostSequentialId,
            rootPostId,
            postParams,
            customParams,
            feedRulesParams,
            rootPostRulesParams,
            quotedPostRulesParams,
            source
        );

        for (uint256 i = 0; i < postParams.extraData.length; i++) {
            _setEntityExtraData(postId, postParams.extraData[i]);
            emit Lens_Feed_Post_ExtraDataAdded(
                postId, postParams.extraData[i].key, postParams.extraData[i].value, postParams.extraData[i].value
            );
        }
        return postId;
    }

    // Overriding the FeedCore
    function _createPost(
        CreatePostParams calldata postParams,
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

    function _forceChecks(uint256 postId, uint256 rootPostId, CreatePostParams calldata postParams) internal view {
        // TODO: Check if the rootPostId == postId case (not a reply, not a repost)
        if (rootPostId != postId) {
            require(Core._postExists(rootPostId), Errors.DoesNotExist());
        }
        if (postParams.quotedPostId != 0) {
            require(Core._postExists(postParams.quotedPostId), Errors.DoesNotExist());
        }
        if (postParams.repliedPostId != 0) {
            require(Core._postExists(postParams.repliedPostId), Errors.DoesNotExist());
            require(rootPostId == Core.$storage().posts[postParams.repliedPostId].rootPostId, Errors.InvalidParameter());
        }
        if (postParams.repostedPostId != 0) {
            require(Core._postExists(postParams.repostedPostId), Errors.DoesNotExist());
            require(postParams.quotedPostId == 0 && postParams.repliedPostId == 0, Errors.InvalidParameter());
            require(rootPostId == Core.$storage().posts[postParams.repostedPostId].rootPostId, Errors.InvalidParameter());
            require(bytes(postParams.contentURI).length == 0, Errors.InvalidParameter());
        }
    }
}
