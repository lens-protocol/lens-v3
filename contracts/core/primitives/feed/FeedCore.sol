// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {EditPostParams, CreatePostParams} from "./../../interfaces/IFeed.sol";

struct PostStorage {
    address author;
    uint256 localSequentialId;
    string contentURI;
    uint256 rootPostId;
    uint256 repostedPostId;
    uint256 quotedPostId;
    uint256 repliedPostId;
    uint80 creationTimestamp;
    address creationSource;
    uint80 lastUpdatedTimestamp;
    address lastUpdateSource;
}

library FeedCore {
    // Storage

    struct Storage {
        string metadataURI;
        uint256 postCount;
        mapping(uint256 => PostStorage) posts;
    }

    // keccak256('lens.feed.core.storage')
    bytes32 constant CORE_STORAGE_SLOT = 0x53e5f3a14c02f725b39e2bf6437f59559b62f544e37322ca762304defb765d0e;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := CORE_STORAGE_SLOT
        }
    }

    // Internal functions - Use these functions to be called as an inlined library

    function _generatePostId(uint256 localSequentialId) internal view returns (uint256) {
        return uint256(keccak256(abi.encode("evm:", block.chainid, address(this), localSequentialId)));
    }

    function _createPost(
        CreatePostParams calldata postParams,
        address source
    ) internal returns (uint256, uint256, uint256) {
        uint256 localSequentialId = ++$storage().postCount;
        uint256 postId = _generatePostId(localSequentialId);
        PostStorage storage _newPost = $storage().posts[postId];
        _newPost.author = postParams.author;
        _newPost.localSequentialId = localSequentialId;
        _newPost.contentURI = postParams.contentURI;
        uint256 rootPostId = postId;
        if (postParams.quotedPostId != 0) {
            _requirePostExistence(postParams.quotedPostId);
            _newPost.quotedPostId = postParams.quotedPostId;
        }
        if (postParams.repliedPostId != 0) {
            _requirePostExistence(postParams.repliedPostId);
            _newPost.repliedPostId = postParams.repliedPostId;
            rootPostId = $storage().posts[postParams.repliedPostId].rootPostId;
        }
        if (postParams.repostedPostId != 0) {
            _requirePostExistence(postParams.repostedPostId);
            _newPost.repostedPostId = postParams.repostedPostId;
            rootPostId = $storage().posts[postParams.repostedPostId].rootPostId;
            require(
                postParams.quotedPostId == 0 && postParams.repliedPostId == 0, "REPOST_CANNOT_HAVE_QUOTED_OR_REPLIED"
            );
            require(bytes(postParams.contentURI).length == 0, "REPOST_CANNOT_HAVE_CONTENT");
        }
        _newPost.rootPostId = rootPostId;
        _newPost.creationTimestamp = uint80(block.timestamp);
        _newPost.creationSource = source;
        _newPost.lastUpdatedTimestamp = uint80(block.timestamp);
        _newPost.lastUpdateSource = source;
        return (postId, localSequentialId, rootPostId);
    }

    function _editPost(uint256 postId, EditPostParams calldata postParams, address source) internal {
        PostStorage storage _post = $storage().posts[postId];
        require(_post.creationTimestamp != 0, "CANNOT_EDIT_NON_EXISTENT_POST"); // Post must exist
        if (_post.repostedPostId != 0) {
            require(bytes(postParams.contentURI).length == 0, "REPOST_CANNOT_HAVE_CONTENT");
        } else {
            _post.contentURI = postParams.contentURI;
        }
        _post.lastUpdatedTimestamp = uint80(block.timestamp);
        _post.lastUpdateSource = source;
    }

    function _deletePost(uint256 postId) internal {
        delete $storage().posts[postId];
    }

    function _requirePostExistence(uint256 postId) internal view {
        require($storage().posts[postId].creationTimestamp != 0, "POST_DOES_NOT_EXIST");
    }

    // TODO: Debate this more. It should be a soft delete, you can reconstruct anyways from tx history.
    // function _disablePost(uint256 postId) internal {
    //      $storage().posts[postId].disabled = true;
    // }
}
