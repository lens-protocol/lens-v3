// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {EditPostParams, CreatePostParams, CreateRepostParams} from "./IFeed.sol";
import "../libraries/ExtraDataLib.sol";

struct PostStorage {
    address author;
    uint256 localSequentialId;
    address source;
    string contentURI;
    uint256 rootPostId;
    bool isRepost;
    uint256 quotedPostId;
    uint256 parentPostId;
    uint80 creationTimestamp;
    uint80 lastUpdatedTimestamp;
    mapping(bytes32 => bytes) extraData;
}

library FeedCore {
    using ExtraDataLib for mapping(bytes32 => bytes);

    // Storage

    struct Storage {
        string metadataURI;
        uint256 postCount;
        mapping(uint256 => PostStorage) posts;
        mapping(bytes32 => bytes) extraData;
    }

    // keccak256('lens.feed.core.storage')
    bytes32 constant CORE_STORAGE_SLOT = 0x53e5f3a14c02f725b39e2bf6437f59559b62f544e37322ca762304defb765d0e;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := CORE_STORAGE_SLOT
        }
    }

    // External functions - Use these functions to be called through DELEGATECALL

    function createPost(CreatePostParams calldata postParams) external returns (uint256, uint256, uint256) {
        return _createPost(postParams);
    }

    function createRepost(CreateRepostParams calldata repostParams) external returns (uint256, uint256, uint256) {
        return _createRepost(repostParams);
    }

    function editPost(uint256 postId, EditPostParams calldata postParams) external {
        _editPost(postId, postParams);
    }

    function deletePost(uint256 postId, bytes32[] calldata extraDataKeysToDelete) external {
        _deletePost(postId, extraDataKeysToDelete);
    }

    function setExtraData(DataElement[] calldata extraDataToSet) external {
        $storage().extraData.set(extraDataToSet);
    }

    // Internal functions - Use these functions to be called as an inlined library

    function _generatePostId(uint256 localSequentialId) internal view returns (uint256) {
        return uint256(keccak256(abi.encode("evm:", block.chainid, address(this), localSequentialId)));
    }

    function _createPost(CreatePostParams calldata postParams) internal returns (uint256, uint256, uint256) {
        uint256 localSequentialId = ++$storage().postCount;
        uint256 postId = _generatePostId(localSequentialId);
        PostStorage storage _newPost = $storage().posts[postId];
        _newPost.author = postParams.author;
        _newPost.localSequentialId = localSequentialId;
        _newPost.source = postParams.source;
        _newPost.contentURI = postParams.contentURI;
        uint256 rootPostId = postId;
        if (postParams.quotedPostId != 0) {
            _requirePostExistence(postParams.quotedPostId);
            _newPost.quotedPostId = postParams.quotedPostId;
        }
        if (postParams.parentPostId != 0) {
            _requirePostExistence(postParams.parentPostId);
            _newPost.parentPostId = postParams.parentPostId;
            rootPostId = $storage().posts[postParams.parentPostId].rootPostId;
        }
        _newPost.rootPostId = rootPostId;
        _newPost.creationTimestamp = uint80(block.timestamp);
        _newPost.lastUpdatedTimestamp = uint80(block.timestamp);
        _newPost.extraData.set(postParams.extraData);
        return (postId, localSequentialId, rootPostId);
    }

    function _createRepost(CreateRepostParams calldata repostParams) internal returns (uint256, uint256, uint256) {
        uint256 localSequentialId = ++$storage().postCount;
        uint256 postId = _generatePostId(localSequentialId);
        PostStorage storage _newPost = $storage().posts[postId];
        _newPost.isRepost = true;
        _newPost.author = repostParams.author;
        _newPost.localSequentialId = localSequentialId;
        _newPost.source = repostParams.source;
        _requirePostExistence(repostParams.parentPostId);
        _newPost.parentPostId = repostParams.parentPostId;
        uint256 rootPostId = $storage().posts[repostParams.parentPostId].rootPostId;
        _newPost.rootPostId = rootPostId;
        _newPost.creationTimestamp = uint80(block.timestamp);
        _newPost.lastUpdatedTimestamp = uint80(block.timestamp);
        _newPost.extraData.set(repostParams.extraData);
        return (postId, localSequentialId, rootPostId);
    }

    function _editPost(uint256 postId, EditPostParams calldata postParams) internal {
        PostStorage storage _post = $storage().posts[postId];
        require(_post.creationTimestamp != 0, "CANNOT_EDIT_NON_EXISTENT_POST"); // Post must exist
        if (_post.isRepost) {
            require(bytes(postParams.contentURI).length == 0, "CANNOT_EDIT_REPOST_CONTENT_URI");
        } else {
            _post.contentURI = postParams.contentURI;
        }
        _post.lastUpdatedTimestamp = uint80(block.timestamp);
        ExtraDataLib._setExtraData(_post.extraData, postParams.extraData);
    }

    // TODO(by: @donosonaumczuk): We should do soft-delete (disable/enable post feature), keep the storage there.
    function _deletePost(uint256 postId, bytes32[] calldata extraDataKeysToDelete) internal {
        for (uint256 i = 0; i < extraDataKeysToDelete.length; i++) {
            delete $storage().posts[postId].extraData[extraDataKeysToDelete[i]];
        }
        delete $storage().posts[postId];
    }

    function _requirePostExistence(uint256 postId) internal view {
        require($storage().posts[postId].creationTimestamp != 0, "POST_DOES_NOT_EXIST");
    }

    // TODO: Debate this more. It should be a soft delete, you can reconstruct anyways from tx history.
    // function _disablePost(uint256 postId) internal {
    //      $storage().posts[postId].disabled = true;
    // }

    function _setExtraData(DataElement[] calldata extraDataToSet) internal {
        $storage().extraData.set(extraDataToSet);
    }
}
