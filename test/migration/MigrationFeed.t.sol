// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IFeed, Post, CreatePostParams} from "contracts/core/interfaces/IFeed.sol";
import {PostCreationParams} from "contracts/migration/MigrationFeed.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract MigrationFeedTest is BaseDeployments {
    IFeed migrationFeed;

    function setUp() public override(BaseDeployments) {
        BaseDeployments.switchMigrationMode(true);
        BaseDeployments.setUp();

        migrationFeed = IFeed(
            lensFactory.deployFeed({
                metadataURI: "some metadata uri",
                owner: makeAddr("FEED_OWNER"),
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );
    }

    function testCreatePost_withForceChecks(
        address author,
        uint256 authorPostSequentialId,
        uint80 creationTimestamp,
        address source
    ) public {
        vm.assume(author != address(0));
        vm.assume(authorPostSequentialId != 0);
        vm.assume(creationTimestamp != 0);
        vm.assume(source != address(0));

        KeyValue[] memory extraData = new KeyValue[](2);
        extraData[0] = KeyValue(keccak256("extraData1"), abi.encode(author, authorPostSequentialId));
        extraData[1] = KeyValue(keccak256("extraData2"), abi.encode(authorPostSequentialId, creationTimestamp));

        PostCreationParams memory postCreationParams = PostCreationParams({
            authorPostSequentialId: authorPostSequentialId,
            creationTimestamp: creationTimestamp,
            source: source
        });

        KeyValue[] memory customParams = new KeyValue[](1);
        customParams[0] = KeyValue(bytes32(0), abi.encode(postCreationParams));

        CreatePostParams memory postParams = CreatePostParams({
            author: author,
            contentURI: string.concat("some content uri: ", vm.toString(author), " ", vm.toString(authorPostSequentialId)),
            repostedPostId: 0,
            quotedPostId: 0,
            repliedPostId: 0,
            ruleChanges: _emptyRuleChangeArray(),
            extraData: extraData
        });

        uint256 postId = migrationFeed.createPost(
            postParams,
            customParams,
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray()
        );

        Post memory post = migrationFeed.getPost(postId);
        assertEq(post.author, author, "Author mismatch");
        assertEq(post.authorPostSequentialId, authorPostSequentialId, "Author post sequential ID mismatch");
        assertEq(post.contentURI, postParams.contentURI, "Content URI mismatch");
        assertEq(post.repostedPostId, postParams.repostedPostId, "Reposted post ID mismatch");
        assertEq(post.quotedPostId, postParams.quotedPostId, "Quoted post ID mismatch");
        assertEq(post.repliedPostId, postParams.repliedPostId, "Replied post ID mismatch");
        assertEq(post.creationTimestamp, creationTimestamp, "Creation timestamp mismatch");
        assertEq(post.creationSource, source, "Creation source mismatch");
        assertEq(post.lastUpdatedTimestamp, creationTimestamp, "Last updated timestamp mismatch");
        assertEq(post.lastUpdateSource, source, "Last update source mismatch");

        assertEq(migrationFeed.getPostExtraData(postId, extraData[0].key), extraData[0].value, "ExtraData1 mismatch");
        assertEq(migrationFeed.getPostExtraData(postId, extraData[1].key), extraData[1].value, "ExtraData2 mismatch");

        assertTrue(migrationFeed.postExists(postId), "Post should exist");
        assertEq(migrationFeed.getPostCount(), 1, "getPostCount() mismatch");
        assertEq(migrationFeed.getPostCount(author), 1, "getPostCount(author) mismatch");
        assertEq(migrationFeed.getPostAuthor(postId), author, "getPostAuthor()   mismatch");
        assertEq(
            migrationFeed.getAuthorPostSequentialId(postId),
            authorPostSequentialId,
            "getAuthorPostSequentialId() mismatch"
        );
        assertEq(
            migrationFeed.getNextPostId(author),
            _generatePostId(address(migrationFeed), author, 2),
            "getNextPostId() mismatch"
        );
    }

    function test_CannotCreatePost_ifAlreadyExists(
        address author,
        uint256 authorPostSequentialId,
        uint80 creationTimestamp,
        address source
    ) public {
        vm.assume(author != address(0));
        vm.assume(authorPostSequentialId != 0);
        vm.assume(creationTimestamp != 0);
        vm.assume(source != address(0));

        PostCreationParams memory postCreationParams = PostCreationParams({
            authorPostSequentialId: authorPostSequentialId,
            creationTimestamp: creationTimestamp,
            source: source
        });

        KeyValue[] memory customParams = new KeyValue[](1);
        customParams[0] = KeyValue(bytes32(0), abi.encode(postCreationParams));

        CreatePostParams memory postParams = CreatePostParams({
            author: author,
            contentURI: "some content uri",
            repostedPostId: 0,
            quotedPostId: 0,
            repliedPostId: 0,
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        migrationFeed.createPost(
            postParams,
            customParams,
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray()
        );

        vm.expectRevert(Errors.AlreadyExists.selector);
        migrationFeed.createPost(
            postParams,
            customParams,
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray()
        );
    }

    function _generatePostId(address feed, address author, uint256 authorPostSequentialId)
        internal
        view
        returns (uint256)
    {
        return uint256(keccak256(abi.encode("evm:", block.chainid, feed, author, authorPostSequentialId)));
    }
}
