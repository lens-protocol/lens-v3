// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {EditPostParams, CreatePostParams} from "contracts/core/interfaces/IFeed.sol";

struct PostStorage {
    address author;
    uint256 authorPostSequentialId;
    uint256 postSequentialId;
    string contentURI;
    uint256 rootPostId;
    uint256 repostedPostId;
    uint256 quotedPostId;
    uint256 repliedPostId;
    uint80 creationTimestamp;
    uint80 lastUpdatedTimestamp;
}

library FeedCore {
    // Storage

    struct Storage {
        uint256 postCount;
        mapping(address => uint256) authorPostCount;
        mapping(uint256 => PostStorage) posts;
    }

    /// @custom:keccak lens.storage.FeedCore
    bytes32 constant STORAGE__FEED_CORE = 0x0ac8a89c1a9da2727c9b15c85fbb8fe7be84a171a628701c1a4b1022d72d46f7;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__FEED_CORE
        }
    }

    // Internal functions - Use these functions to be called as an inlined library

    function _generatePostId(address author, uint256 authorPostSequentialId) internal view returns (uint256) {
        return uint256(keccak256(abi.encode("evm:", block.chainid, address(this), author, authorPostSequentialId)));
    }

    function _createPost(CreatePostParams calldata postParams) internal returns (uint256, uint256, uint256) {
        uint256 postSequentialId = ++$storage().postCount;
        uint256 authorPostSequentialId = ++$storage().authorPostCount[postParams.author];
        uint256 postId = _generatePostId(postParams.author, authorPostSequentialId);
        PostStorage storage _newPost = $storage().posts[postId];
        _newPost.author = postParams.author;
        _newPost.authorPostSequentialId = authorPostSequentialId;
        _newPost.postSequentialId = postSequentialId;
        _newPost.contentURI = postParams.contentURI;
        uint256 rootPostId = postId;
        if (postParams.quotedPostId != 0) {
            require(_postExists(postParams.quotedPostId), "QUOTED_POST_DOES_NOT_EXIST");
            _newPost.quotedPostId = postParams.quotedPostId;
        }
        if (postParams.repliedPostId != 0) {
            require(_postExists(postParams.repliedPostId), "REPLIED_POST_DOES_NOT_EXIST");
            _newPost.repliedPostId = postParams.repliedPostId;
            rootPostId = $storage().posts[postParams.repliedPostId].rootPostId;
        }
        if (postParams.repostedPostId != 0) {
            require(_postExists(postParams.repostedPostId), "REPOSTED_POST_DOES_NOT_EXIST");
            _newPost.repostedPostId = postParams.repostedPostId;
            rootPostId = $storage().posts[postParams.repostedPostId].rootPostId;
            require(
                postParams.quotedPostId == 0 && postParams.repliedPostId == 0, "REPOST_CANNOT_HAVE_QUOTED_OR_REPLIED"
            );
            require(bytes(postParams.contentURI).length == 0, "REPOST_CANNOT_HAVE_CONTENT");
        }
        _newPost.rootPostId = rootPostId;
        _newPost.creationTimestamp = uint80(block.timestamp);
        _newPost.lastUpdatedTimestamp = uint80(block.timestamp);
        return (postId, postSequentialId, rootPostId);
    }

    function _editPost(uint256 postId, EditPostParams calldata postParams) internal {
        PostStorage storage _post = $storage().posts[postId];
        require(_post.creationTimestamp != 0, "CANNOT_EDIT_NON_EXISTENT_POST"); // Post must exist
        if (_post.repostedPostId != 0) {
            require(bytes(postParams.contentURI).length == 0, "REPOST_CANNOT_HAVE_CONTENT");
        } else {
            _post.contentURI = postParams.contentURI;
        }
        _post.lastUpdatedTimestamp = uint80(block.timestamp);
    }

    function _removePost(uint256 postId) internal {
        delete $storage().posts[postId];
    }

    function _postExists(uint256 postId) internal view returns (bool) {
        return $storage().posts[postId].creationTimestamp != 0;
    }
}
