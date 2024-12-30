// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue, RuleProcessingParams} from "./../core/types/Types.sol";
import {CreatePostParams} from "./../core/interfaces/IFeed.sol";
import {FeedCore as Core, PostStorage} from "./../core/primitives/feed/FeedCore.sol";
import {Feed} from "./../core/primitives/feed/Feed.sol";
import {IAccessControl} from "./../core/interfaces/IAccessControl.sol";

contract MigrationFeed is Feed {
    constructor(string memory metadataURI, IAccessControl accessControl) Feed(metadataURI, accessControl) {}

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
            uint80 creationTimestamp
        ) = abi.decode(customParams[0].value, (uint256, uint256, uint256, uint256, uint80));
        _createPost(postParams, postId, rootPostId, postSequentialId, authorPostSequentialId, creationTimestamp);

        // TODO: _setPrimitiveInternalExtraDataForEntity(postId, KeyValue(LAST_UPDATED_SOURCE_EXTRA_DATA, abi.encode(source)));

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
            address(0) // TODO: Think if we want to pass the migrator as source
        );

        // TODO: Do we keep the extraData?
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
        _newPost.lastUpdatedTimestamp = creationTimestamp; // TODO: Maybe block.timestamp?
    }
}
