// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue, RuleProcessingParams} from "./../core/types/Types.sol";
import {CreatePostParams} from "./../core/interfaces/IFeed.sol";
import {FeedCore as Core, PostStorage} from "./../core/primitives/feed/FeedCore.sol";
import {Feed} from "./../core/primitives/feed/Feed.sol";
import {IAccessControl} from "./../core/interfaces/IAccessControl.sol";

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
}
