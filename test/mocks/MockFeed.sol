// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {Post} from "contracts/core/interfaces/IFeed.sol";

contract MockFeed {
    address internal _postAuthor;
    bool internal _postExists = true;
    string internal _contentURI = "someContentURI";
    uint80 internal _creationTimestamp = uint80(block.timestamp);

    function setPostAuthor(uint256, /* postId */ address author) external {
        _postAuthor = author;
    }

    function getPostAuthor(uint256 /* postId */ ) external view returns (address) {
        return _postAuthor;
    }

    function setPostExists(bool exists) external {
        _postExists = exists;
    }

    function postExists(uint256 /* postId */ ) external view returns (bool) {
        return _postExists;
    }

    function setContentURI(string memory contentURI) external {
        _contentURI = contentURI;
    }

    function getContentURI(uint256 /* postId */ ) external view returns (string memory) {
        return _contentURI;
    }

    function getPost(uint256 postId) external view returns (Post memory) {
        return Post({
            author: _postAuthor,
            authorPostSequentialId: 1,
            postSequentialId: 1,
            contentURI: _contentURI,
            rootPostId: postId,
            repostedPostId: 0,
            quotedPostId: 0,
            repliedPostId: 0,
            creationTimestamp: _creationTimestamp,
            creationSource: address(0),
            lastUpdatedTimestamp: _creationTimestamp,
            lastUpdateSource: address(0),
            isDeleted: false
        });
    }
}
