// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue, RuleProcessingParams} from "contracts/core/types/Types.sol";
import {CreatePostParams} from "contracts/core/interfaces/IFeed.sol";
import {FeedCore as Core, PostStorage} from "contracts/core/primitives/feed/FeedCore.sol";
import {Feed} from "contracts/core/primitives/feed/Feed.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";
import {ExtraDataLib} from "contracts/core/libraries/ExtraDataLib.sol";

struct PostCreationParams {
    uint256 authorPostSequentialId;
    uint80 creationTimestamp;
    address source;
}

contract MigrationFeed is Feed, EventEmitter {
    using ExtraDataLib for mapping(bytes32 => bytes);

    function $migrationExtraDataStorage() private pure returns (ExtraDataStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__EXTRA_STORAGE
        }
    }

    function createPost(
        CreatePostParams memory postParams,
        KeyValue[] memory customParams,
        RuleProcessingParams[] memory feedRulesParams,
        RuleProcessingParams[] memory rootPostRulesParams,
        RuleProcessingParams[] memory quotedPostRulesParams
    ) external override returns (uint256) {
        require(customParams.length > 0, Errors.InvalidParameter());
        PostCreationParams memory postCreationParams = abi.decode(customParams[0].value, (PostCreationParams));
        (uint256 postId, uint256 rootPostId) =
            _createPost(postParams, postCreationParams.authorPostSequentialId, postCreationParams.creationTimestamp);

        if (postCreationParams.source != address(0)) {
            // Trust the migrator, no source verification
            _setEntityExtraData(postId, KeyValue(DATA__SOURCE, abi.encode(postCreationParams.source)));
            _setEntityExtraData(postId, KeyValue(DATA__LAST_UPDATED_SOURCE, abi.encode(postCreationParams.source)));
        }

        emit Lens_Feed_PostCreated(
            postId,
            postParams.author,
            postCreationParams.authorPostSequentialId,
            rootPostId,
            postParams,
            customParams,
            feedRulesParams,
            rootPostRulesParams,
            quotedPostRulesParams,
            postCreationParams.source
        );

        for (uint256 i = 0; i < postParams.extraData.length; i++) {
            _migration_forceExtraData(postParams.author, postId, postParams.extraData[i]);
            emit Lens_Feed_Post_ExtraDataAdded(
                postId, postParams.extraData[i].key, postParams.extraData[i].value, postParams.extraData[i].value
            );
        }
        return postId;
    }

    function _migration_forceExtraData(address addr, uint256 entityId, KeyValue memory extraDataToSet)
        private
        returns (bool)
    {
        // In this release we always set the entityID to zero
        bool wasPreviousValueSet = $migrationExtraDataStorage().extraStorage[addr][0][entityId].set(extraDataToSet);
        emit Lens_ExtraDataSet(addr, entityId, extraDataToSet.key, extraDataToSet.value);
        return wasPreviousValueSet;
    }

    // Overriding the FeedCore
    function _createPost(CreatePostParams memory postParams, uint256 authorPostSequentialId, uint80 creationTimestamp)
        internal
        returns (uint256, uint256)
    {
        require(authorPostSequentialId != 0, Errors.InvalidParameter());
        require(creationTimestamp != 0, Errors.InvalidParameter());

        uint256 postSequentialId = ++Core.$storage().postCount;
        Core.$storage().authorPostCount[postParams.author]++;
        uint256 postId = Core._generatePostId(postParams.author, authorPostSequentialId);
        require(Core._postExists(postId) == false, Errors.AlreadyExists());
        PostStorage storage _newPost = Core.$storage().posts[postId];

        _newPost.author = postParams.author;
        _newPost.authorPostSequentialId = authorPostSequentialId;
        _newPost.postSequentialId = postSequentialId;
        _newPost.contentURI = postParams.contentURI;

        uint256 rootPostId = postId;

        if (postParams.quotedPostId != 0) {
            require(Core._postExists(postParams.quotedPostId), Errors.DoesNotExist());
            _newPost.quotedPostId = postParams.quotedPostId;
        }
        if (postParams.repliedPostId != 0) {
            require(Core._postExists(postParams.repliedPostId), Errors.DoesNotExist());
            _newPost.repliedPostId = postParams.repliedPostId;
            rootPostId = Core.$storage().posts[postParams.repliedPostId].rootPostId;
        }
        if (postParams.repostedPostId != 0) {
            require(Core._postExists(postParams.repostedPostId), Errors.DoesNotExist());
            _newPost.repostedPostId = postParams.repostedPostId;
            rootPostId = Core.$storage().posts[postParams.repostedPostId].rootPostId;
            require(postParams.quotedPostId == 0 && postParams.repliedPostId == 0, Errors.InvalidParameter());
            require(bytes(postParams.contentURI).length == 0, Errors.InvalidParameter());
        }
        if (rootPostId != postId) {
            require(Core._postExists(rootPostId), Errors.DoesNotExist());
        }
        _newPost.rootPostId = rootPostId;
        _newPost.creationTimestamp = creationTimestamp;
        _newPost.lastUpdatedTimestamp = creationTimestamp;
        return (postId, rootPostId);
    }
}
