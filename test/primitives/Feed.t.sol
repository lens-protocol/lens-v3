// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {Errors} from "@core/types/Errors.sol";
import {Feed} from "@core/primitives/feed/Feed.sol";
import {IFeed, CreatePostParams, EditPostParams, Post} from "@core/interfaces/IFeed.sol";
import {IFeedRule} from "@core/interfaces/IFeedRule.sol";
import {IMetadataBased} from "@core/interfaces/IMetadataBased.sol";
import {IPostRule} from "@core/interfaces/IPostRule.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {MockRule} from "test/mocks/MockRule.sol";
import {
    Rule,
    RuleChange,
    RuleConfigurationChange,
    RuleSelectorChange,
    KeyValue,
    RuleProcessingParams
} from "@core/types/Types.sol";
import {RuleExecutionTest} from "test/primitives/rules/RuleExecution.t.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";

contract FeedTest is RulesTest, BaseDeployments, RuleExecutionTest {
    IFeed feed;

    address feedForRules;
    MockAccessControl mockAccessControl;

    address author = makeAddr("AUTHOR");
    address feedOwner = makeAddr("FEED_OWNER");

    function setUp() public virtual override(RulesTest, BaseDeployments, RuleExecutionTest) {
        BaseDeployments.setUp();

        mockAccessControl = new MockAccessControl();

        vm.prank(address(lensFactory));
        feed = IFeed(
            feedFactory.deployFeed({
                metadataURI: "some metadata uri",
                accessControl: mockAccessControl,
                proxyAdminOwner: address(this),
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        vm.prank(address(lensFactory));
        feedForRules = feedFactory.deployFeed({
            metadataURI: "uri://feed",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        RulesTest.setUp();
        RuleExecutionTest.setUp();
    }

    function test_CreatePost(address postAuthor, string memory contentURI) public {
        vm.assume(postAuthor != address(0));
        vm.assume(bytes(contentURI).length > 0);

        uint256 expectedPostSequentialId = feed.getPostCount() + 1;
        uint256 expectedAuthorPostSequentialId = feed.getPostCount(postAuthor) + 1;

        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_PostCreated(
            feed.getNextPostId(postAuthor),
            postAuthor,
            expectedAuthorPostSequentialId,
            feed.getNextPostId(postAuthor),
            CreatePostParams({
                author: postAuthor,
                contentURI: contentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            _emptyKeyValueArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            address(0)
        );

        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: contentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        assertTrue(feed.postExists(postId), "Post should exist");
        assertEq(feed.getPostAuthor(postId), postAuthor, "Post author should match");
        assertEq(feed.getPostCount(), expectedPostSequentialId, "Global post count should increment");
        assertEq(feed.getPostCount(postAuthor), expectedAuthorPostSequentialId, "Author post count should increment");

        Post memory post = feed.getPost(postId);
        assertEq(post.author, postAuthor, "Post author should match");
        assertEq(post.contentURI, contentURI, "Content URI should match");
        assertEq(post.postSequentialId, expectedPostSequentialId, "Post sequential ID should match");
        assertEq(post.authorPostSequentialId, expectedAuthorPostSequentialId, "Author post sequential ID should match");
        assertEq(post.rootPostId, postId, "Root post ID should be self for new post");
        assertEq(post.repostedPostId, 0, "Reposted post ID should be 0");
        assertEq(post.quotedPostId, 0, "Quoted post ID should be 0");
        assertEq(post.repliedPostId, 0, "Replied post ID should be 0");
        assertEq(post.creationTimestamp, block.timestamp, "Creation timestamp should be current block");
        assertEq(post.lastUpdatedTimestamp, block.timestamp, "Last updated timestamp should be current block");
        assertEq(post.creationSource, address(0), "Creation source should be 0 address");
        assertEq(post.lastUpdateSource, address(0), "Last update source should be 0 address");
    }

    function test_CreatePost_MatchingExpectedPostId(address postAuthor, string memory contentURI) public {
        vm.assume(postAuthor != address(0));
        vm.assume(bytes(contentURI).length > 0);

        uint256 expectedPostSequentialId = feed.getPostCount() + 1;
        uint256 expectedAuthorPostSequentialId = feed.getPostCount(postAuthor) + 1;

        uint256 expectedPostId = feed.getNextPostId(postAuthor);

        KeyValue[] memory customParams =
            _toKeyValueArray(KeyValue({key: keccak256("lens.param.expectedPostId"), value: abi.encode(expectedPostId)}));

        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_PostCreated(
            expectedPostId,
            postAuthor,
            expectedAuthorPostSequentialId,
            expectedPostId,
            CreatePostParams({
                author: postAuthor,
                contentURI: contentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams,
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            address(0)
        );

        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: contentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: customParams,
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        assertTrue(feed.postExists(postId), "Post should exist");
        assertEq(feed.getPostAuthor(postId), postAuthor, "Post author should match");
        assertEq(feed.getPostCount(), expectedPostSequentialId, "Global post count should increment");
        assertEq(feed.getPostCount(postAuthor), expectedAuthorPostSequentialId, "Author post count should increment");
    }

    function test_CannotCreatePost_IfExpectedPostIdDoesNotMatch(
        address postAuthor,
        uint256 wrongExpectedPostId,
        string memory contentURI
    ) public {
        vm.assume(postAuthor != address(0));
        vm.assume(bytes(contentURI).length > 0);
        uint256 expectedPostId = feed.getNextPostId(postAuthor);
        vm.assume(wrongExpectedPostId != expectedPostId);

        vm.prank(postAuthor);
        vm.expectRevert(Errors.UnexpectedValue.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: contentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _toKeyValueArray(
                KeyValue({key: keccak256("lens.param.expectedPostId"), value: abi.encode(wrongExpectedPostId)})
            ),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotCreatePost_DifferentSender(address postAuthor, address sender) public {
        vm.assume(postAuthor != address(0));
        vm.assume(sender != address(0));
        vm.assume(sender != postAuthor);

        vm.prank(sender);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "some content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotCreatePost_ZeroAddress() public {
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: address(0),
                contentURI: "some content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    // TODO: Should we allow empty content URI?
    function test_CreatePost_WithEmptyContentURI(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        assertTrue(feed.postExists(postId), "Post should exist");
        Post memory post = feed.getPost(postId);
        assertEq(post.contentURI, "", "Content URI should be empty");
    }

    function test_CreateRepost(address postAuthor, address reposter) public {
        vm.assume(postAuthor != address(0));
        vm.assume(reposter != address(0));
        vm.assume(reposter != postAuthor);

        // First create an original post
        vm.prank(postAuthor);
        uint256 originalPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Then create a repost
        vm.prank(reposter);
        uint256 repostId = feed.createPost({
            postParams: CreatePostParams({
                author: reposter,
                contentURI: "",
                repostedPostId: originalPostId,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        assertTrue(feed.postExists(repostId), "Repost should exist");
        Post memory repost = feed.getPost(repostId);
        assertEq(repost.author, reposter, "Repost author should match");
        assertEq(repost.contentURI, "", "Repost content URI should be empty");
        assertEq(repost.repostedPostId, originalPostId, "Reposted post ID should match original");
        assertEq(repost.rootPostId, originalPostId, "Root post ID should match original");
        assertEq(repost.quotedPostId, 0, "Quoted post ID should be 0");
        assertEq(repost.repliedPostId, 0, "Replied post ID should be 0");
    }

    function test_CannotCreateRepost_WithContentURI(address postAuthor, address reposter) public {
        vm.assume(postAuthor != address(0));
        vm.assume(reposter != address(0));
        vm.assume(reposter != postAuthor);

        // First create an original post
        vm.prank(postAuthor);
        uint256 originalPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to create a repost with content URI
        vm.prank(reposter);
        vm.expectRevert(Errors.InvalidParameter.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: reposter,
                contentURI: "some content uri",
                repostedPostId: originalPostId,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotCreateRepost_WithReplyOrQuote(address postAuthor, address reposter) public {
        vm.assume(postAuthor != address(0));
        vm.assume(reposter != address(0));
        vm.assume(reposter != postAuthor);

        // First create an original post
        vm.prank(postAuthor);
        uint256 originalPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to create a repost with reply
        vm.prank(reposter);
        vm.expectRevert(Errors.InvalidParameter.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: reposter,
                contentURI: "",
                repostedPostId: originalPostId,
                quotedPostId: 0,
                repliedPostId: originalPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to create a repost with quote
        vm.prank(reposter);
        vm.expectRevert(Errors.InvalidParameter.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: reposter,
                contentURI: "",
                repostedPostId: originalPostId,
                quotedPostId: originalPostId,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CreateQuote(address postAuthor, address quoter, string memory quoteContentURI) public {
        vm.assume(postAuthor != address(0));
        vm.assume(quoter != address(0));
        vm.assume(quoter != postAuthor);
        vm.assume(bytes(quoteContentURI).length > 0);

        // First create an original post
        vm.prank(postAuthor);
        uint256 originalPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create a quote post
        vm.prank(quoter);
        uint256 quoteId = feed.createPost({
            postParams: CreatePostParams({
                author: quoter,
                contentURI: quoteContentURI,
                repostedPostId: 0,
                quotedPostId: originalPostId,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        assertTrue(feed.postExists(quoteId), "Quote should exist");
        Post memory quote = feed.getPost(quoteId);
        assertEq(quote.author, quoter, "Quote author should match");
        assertEq(quote.contentURI, quoteContentURI, "Quote content URI should match");
        assertEq(quote.quotedPostId, originalPostId, "Quoted post ID should match original");
        assertEq(quote.rootPostId, quoteId, "Root post ID should be self for quote");
        assertEq(quote.repostedPostId, 0, "Reposted post ID should be 0");
        assertEq(quote.repliedPostId, 0, "Replied post ID should be 0");
    }

    // TODO: Should we allow empty content URI in a quote? For reply with quote - yeah, but just for a separate quote?
    function test_Quote_WithEmptyContentURI(address postAuthor, address quoter) public {
        vm.assume(postAuthor != address(0));
        vm.assume(quoter != address(0));
        vm.assume(quoter != postAuthor);

        // First create an original post
        vm.prank(postAuthor);
        uint256 originalPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to create a repost with content URI
        vm.prank(quoter);
        uint256 quoteId = feed.createPost({
            postParams: CreatePostParams({
                author: quoter,
                contentURI: "",
                repostedPostId: originalPostId,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        Post memory quote = feed.getPost(quoteId);
        assertEq(quote.contentURI, "", "Quote content URI should be empty");
    }

    function test_CreateReply(address postAuthor, address replier, string memory replyContentURI) public {
        vm.assume(postAuthor != address(0));
        vm.assume(replier != address(0));
        vm.assume(replier != postAuthor);
        vm.assume(bytes(replyContentURI).length > 0);

        // First create an original post
        vm.prank(postAuthor);
        uint256 originalPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create a reply post
        vm.prank(replier);
        uint256 replyId = feed.createPost({
            postParams: CreatePostParams({
                author: replier,
                contentURI: replyContentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: originalPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        assertTrue(feed.postExists(replyId), "Reply should exist");
        Post memory reply = feed.getPost(replyId);
        assertEq(reply.author, replier, "Reply author should match");
        assertEq(reply.contentURI, replyContentURI, "Reply content URI should match");
        assertEq(reply.repliedPostId, originalPostId, "Replied post ID should match original");
        assertEq(reply.rootPostId, originalPostId, "Root post ID should match original for reply");
        assertEq(reply.repostedPostId, 0, "Reposted post ID should be 0");
        assertEq(reply.quotedPostId, 0, "Quoted post ID should be 0");
    }

    function test_CannotQuoteOrReply_NonexistentPost(address postAuthor, uint256 nonexistentPostId) public {
        vm.assume(postAuthor != address(0));
        vm.assume(nonexistentPostId != 0);
        vm.assume(!feed.postExists(nonexistentPostId));

        // Try to create a quote of nonexistent post
        vm.prank(postAuthor);
        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "quote content uri",
                repostedPostId: 0,
                quotedPostId: nonexistentPostId,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to create a reply to nonexistent post
        vm.prank(postAuthor);
        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "reply content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: nonexistentPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_RootPostId_Inheritance(address postAuthor, address replier, address reposter) public {
        vm.assume(postAuthor != address(0));
        vm.assume(replier != address(0));
        vm.assume(reposter != address(0));
        vm.assume(replier != postAuthor);
        vm.assume(reposter != postAuthor);
        vm.assume(reposter != replier);

        // Create original post
        vm.prank(postAuthor);
        uint256 originalPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create reply to original post
        vm.prank(replier);
        uint256 replyId = feed.createPost({
            postParams: CreatePostParams({
                author: replier,
                contentURI: "reply content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: originalPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create repost of reply
        vm.prank(reposter);
        uint256 repostId = feed.createPost({
            postParams: CreatePostParams({
                author: reposter,
                contentURI: "",
                repostedPostId: replyId,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create quote of original post (should have its own root)
        vm.prank(replier);
        uint256 quoteId = feed.createPost({
            postParams: CreatePostParams({
                author: replier,
                contentURI: "quote content uri",
                repostedPostId: 0,
                quotedPostId: originalPostId,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create quote of original post (should have its own root)
        vm.prank(replier);
        uint256 replyWithQuoteId = feed.createPost({
            postParams: CreatePostParams({
                author: replier,
                contentURI: "reply with quote content uri",
                repostedPostId: 0,
                quotedPostId: originalPostId,
                repliedPostId: replyId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify root post IDs
        Post memory originalPost = feed.getPost(originalPostId);
        Post memory reply = feed.getPost(replyId);
        Post memory repost = feed.getPost(repostId);
        Post memory quote = feed.getPost(quoteId);
        Post memory replyWithQuote = feed.getPost(replyWithQuoteId);

        assertEq(originalPost.rootPostId, originalPostId, "Original post should be its own root");
        assertEq(reply.rootPostId, originalPostId, "Reply should inherit root from original post");
        assertEq(repost.rootPostId, originalPostId, "Repost of reply should inherit root from original post");
        assertEq(quote.rootPostId, quoteId, "Quote should be its own root");
        assertEq(replyWithQuote.rootPostId, originalPostId, "Reply with quote should inherit root from original post");
    }

    function test_EditPost(address postAuthor, string memory contentURI, string memory newContentURI) public {
        vm.assume(postAuthor != address(0));
        vm.assume(bytes(contentURI).length > 0);
        vm.assume(bytes(newContentURI).length > 0);
        vm.assume(keccak256(bytes(contentURI)) != keccak256(bytes(newContentURI)));

        // Create original post
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: contentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Store original post data
        Post memory originalPost = feed.getPost(postId);

        // Edit the post
        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_PostEdited(
            postId,
            postAuthor,
            EditPostParams({contentURI: newContentURI, extraData: _emptyKeyValueArray()}),
            _emptyKeyValueArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            address(0)
        );

        vm.prank(postAuthor);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams({contentURI: newContentURI, extraData: _emptyKeyValueArray()}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify post was edited correctly
        Post memory editedPost = feed.getPost(postId);
        assertEq(editedPost.contentURI, newContentURI, "Content URI should be updated");

        // Verify other fields remain unchanged
        assertEq(editedPost.author, originalPost.author, "Author should not change");
        assertEq(editedPost.postSequentialId, originalPost.postSequentialId, "Post sequential ID should not change");
        assertEq(
            editedPost.authorPostSequentialId,
            originalPost.authorPostSequentialId,
            "Author post sequential ID should not change"
        );
        assertEq(editedPost.rootPostId, originalPost.rootPostId, "Root post ID should not change");
        assertEq(editedPost.repostedPostId, originalPost.repostedPostId, "Reposted post ID should not change");
        assertEq(editedPost.quotedPostId, originalPost.quotedPostId, "Quoted post ID should not change");
        assertEq(editedPost.repliedPostId, originalPost.repliedPostId, "Replied post ID should not change");
        assertEq(editedPost.creationTimestamp, originalPost.creationTimestamp, "Creation timestamp should not change");
        assertEq(editedPost.creationSource, originalPost.creationSource, "Creation source should not change");

        // Check if last update source & timestamp is correct
        // TODO: Test with a source
        assertEq(editedPost.lastUpdateSource, address(0), "Last update source should be 0 address");
        assertTrue(
            editedPost.lastUpdatedTimestamp >= originalPost.lastUpdatedTimestamp,
            "Last updated timestamp should be updated"
        );
    }

    function test_CannotEditPost_DifferentSender(address postAuthor, address differentSender) public {
        vm.assume(postAuthor != address(0));
        vm.assume(differentSender != address(0));
        vm.assume(differentSender != postAuthor);

        // Create original post
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to edit the post with a different sender
        vm.prank(differentSender);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams({contentURI: "new content uri", extraData: _emptyKeyValueArray()}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotEditPost_NonexistentPost(address postAuthor, uint256 nonexistentPostId) public {
        vm.assume(postAuthor != address(0));
        vm.assume(nonexistentPostId != 0);
        vm.assume(!feed.postExists(nonexistentPostId));

        vm.prank(postAuthor);
        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.editPost({
            postId: nonexistentPostId,
            postParams: EditPostParams({contentURI: "new content uri", extraData: _emptyKeyValueArray()}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotEditPost_AfterDeletion(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        // Create a post
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Delete the post
        vm.prank(postAuthor);
        feed.deletePost({
            postId: postId,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to edit the deleted post
        vm.prank(postAuthor);
        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams({contentURI: "new content uri", extraData: _emptyKeyValueArray()}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_EditPost_UpdatesTimestamp(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        // Create a post
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        Post memory originalPost = feed.getPost(postId);

        // Warp to a future timestamp
        vm.warp(block.timestamp + 1 hours);

        // Edit the post
        vm.prank(postAuthor);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams({contentURI: "new content uri", extraData: _emptyKeyValueArray()}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        Post memory editedPost = feed.getPost(postId);

        // Verify timestamps
        assertEq(editedPost.creationTimestamp, originalPost.creationTimestamp, "Creation timestamp should not change");
        assertEq(
            editedPost.lastUpdatedTimestamp, uint80(block.timestamp), "Last updated timestamp should be current block"
        );
        assertTrue(
            editedPost.lastUpdatedTimestamp > originalPost.lastUpdatedTimestamp, "Last updated timestamp should increase"
        );
    }

    function test_CannotEditRepost_WithContentURI(address postAuthor, address reposter) public {
        vm.assume(postAuthor != address(0));
        vm.assume(reposter != address(0));
        vm.assume(reposter != postAuthor);

        // Create original post
        vm.prank(postAuthor);
        uint256 originalPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create repost
        vm.prank(reposter);
        uint256 repostId = feed.createPost({
            postParams: CreatePostParams({
                author: reposter,
                contentURI: "",
                repostedPostId: originalPostId,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to edit repost with content URI
        vm.prank(reposter);
        vm.expectRevert(Errors.InvalidParameter.selector);
        feed.editPost({
            postId: repostId,
            postParams: EditPostParams({contentURI: "new content uri", extraData: _emptyKeyValueArray()}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_DeletePost(address postAuthor, string memory contentURI) public {
        vm.assume(postAuthor != address(0));
        vm.assume(bytes(contentURI).length > 0);

        // Create a post
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: contentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify post exists before deletion
        assertTrue(feed.postExists(postId), "Post should exist before deletion");

        // Delete the post
        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_PostDeleted(postId, postAuthor, _emptyKeyValueArray(), address(0));

        vm.prank(postAuthor);
        feed.deletePost({
            postId: postId,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify post no longer exists
        assertFalse(feed.postExists(postId), "Post should not exist after deletion");

        // Try to get the post - should revert
        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.getPost(postId);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override(RulesTest, RuleExecutionTest) {
        IFeed(feedForRules).changeFeedRules(ruleChanges);
    }

    function _primitiveAddress() internal view override returns (address) {
        return feedForRules;
    }

    function _aValidRuleSelector() internal pure override returns (bytes4) {
        return IFeedRule.processCreatePost.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IFeedRule.processCreatePost.selector;
        selectors[1] = IFeedRule.processEditPost.selector;
        selectors[2] = IFeedRule.processDeletePost.selector;
        selectors[3] = IFeedRule.processPostRuleChanges.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return IFeed(feedForRules).getFeedRules(selector, required);
    }

    function _configureRuleSelector() internal pure override(RulesTest, RuleExecutionTest) returns (bytes4) {
        return IFeedRule.configure.selector;
    }

    function _generatePostId(address _feed, address _author, uint256 _authorPostSequentialId)
        internal
        view
        returns (uint256)
    {
        return uint256(keccak256(abi.encode("evm:", block.chainid, address(_feed), _author, _authorPostSequentialId)));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}

contract FeedTest2 is RulesTest, BaseDeployments, RuleExecutionTest {
    IFeed feed;

    address feedForRules;
    MockAccessControl mockAccessControl;

    address author = makeAddr("AUTHOR");
    address feedOwner = makeAddr("FEED_OWNER");

    function setUp() public virtual override(RulesTest, BaseDeployments, RuleExecutionTest) {
        BaseDeployments.setUp();

        mockAccessControl = new MockAccessControl();

        vm.prank(address(lensFactory));
        feed = IFeed(
            feedFactory.deployFeed({
                metadataURI: "some metadata uri",
                accessControl: mockAccessControl,
                proxyAdminOwner: address(this),
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        vm.prank(address(lensFactory));
        feedForRules = feedFactory.deployFeed({
            metadataURI: "uri://feed",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        RulesTest.setUp();
        RuleExecutionTest.setUp();
    }

    function test_SetPostExtraData(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        // Create a post first
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "some content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        bytes32 key = bytes32("test.key");
        bytes memory value = abi.encode("test value");
        KeyValue[] memory extraData = new KeyValue[](1);
        extraData[0] = KeyValue(key, value);

        // Set extra data through post creation
        vm.prank(postAuthor);
        uint256 postIdWithExtra = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "content with extra",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: extraData
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Set extra data through post edit
        vm.prank(postAuthor);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams({contentURI: "edited content", extraData: extraData}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify extra data was set correctly in both cases
        assertEq(feed.getPostExtraData(postId, key), value, "Extra data should be set via edit");
        assertEq(feed.getPostExtraData(postIdWithExtra, key), value, "Extra data should be set via creation");
    }

    function test_GetPostExtraData_NonexistentPost(uint256 nonexistentPostId, bytes32 key) public {
        vm.assume(!feed.postExists(nonexistentPostId));

        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.getPostExtraData(nonexistentPostId, key);
    }

    function test_GetPostExtraData_NonexistentKey(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        // Create a post without extra data
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "some content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        bytes32 nonexistentKey = bytes32("nonexistent.key");
        assertEq(feed.getPostExtraData(postId, nonexistentKey), "", "Should return empty bytes for nonexistent key");
    }

    function test_CannotAddRules_NonRootPost(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processCreatePost.selector, isRequired: true, enabled: true});

        // Create a root post first
        vm.prank(postAuthor);
        uint256 rootPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "root post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to create a reply with rules (should fail)
        vm.prank(postAuthor);
        vm.expectRevert(Errors.CannotHaveRules.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "reply with rules",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: rootPostId,
                ruleChanges: ruleChanges,
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to create a repost with rules (should fail)
        vm.prank(postAuthor);
        vm.expectRevert(Errors.CannotHaveRules.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "",
                repostedPostId: rootPostId,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: ruleChanges,
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_EditPost_WithExtraData_Add() public {
        string memory contentURI = "ipfs://original";
        bytes32 key = bytes32("test.key");
        bytes memory value = abi.encode("test.value");

        // Create post first
        vm.prank(author);
        uint256 postId = feed.createPost({
            postParams: _getCreatePostParams(contentURI, author),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Edit post and add extra data
        KeyValue[] memory extraData = new KeyValue[](1);
        extraData[0] = KeyValue(key, value);

        vm.prank(author);
        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_Post_ExtraDataAdded(postId, key, value, value);

        feed.editPost({
            postId: postId,
            postParams: EditPostParams(contentURI, extraData),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify extra data was stored
        assertEq(feed.getPostExtraData(postId, key), value);
    }

    function _getCreatePostParams(string memory contentURI) internal view returns (CreatePostParams memory) {
        return CreatePostParams({
            author: msg.sender,
            contentURI: contentURI,
            quotedPostId: 0,
            repliedPostId: 0,
            repostedPostId: 0,
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function _getCreatePostParams(string memory contentURI, address _author)
        internal
        pure
        returns (CreatePostParams memory)
    {
        return CreatePostParams({
            author: _author,
            contentURI: contentURI,
            quotedPostId: 0,
            repliedPostId: 0,
            repostedPostId: 0,
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function test_EditPost_WithExtraData_Update() public {
        string memory contentURI = "ipfs://original";
        bytes32 key = bytes32("test.key");
        bytes memory initialValue = abi.encode("initial.value");
        bytes memory updatedValue = abi.encode("updated.value");

        // Create post with initial extra data
        KeyValue[] memory initialExtraData = new KeyValue[](1);
        initialExtraData[0] = KeyValue(key, initialValue);

        vm.prank(author);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: contentURI,
                quotedPostId: 0,
                repliedPostId: 0,
                repostedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: initialExtraData
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify initial extra data was stored
        assertEq(feed.getPostExtraData(postId, key), initialValue);

        // Update extra data
        KeyValue[] memory updatedExtraData = new KeyValue[](1);
        updatedExtraData[0] = KeyValue(key, updatedValue);

        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_Post_ExtraDataUpdated(postId, key, updatedValue, updatedValue);

        vm.prank(author);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams(contentURI, updatedExtraData),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify extra data was updated
        assertEq(feed.getPostExtraData(postId, key), updatedValue);
    }

    function test_CreatePost_WithExtraData() public {
        string memory contentURI = "ipfs://original";
        bytes32 key = bytes32("test.key");
        bytes memory value = abi.encode("test.value");

        // Create post with extra data
        KeyValue[] memory extraData = new KeyValue[](1);
        extraData[0] = KeyValue(key, value);

        uint256 expectedPostId = _generatePostId(address(feed), author, 1);

        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_Post_ExtraDataAdded(expectedPostId, key, value, value);

        vm.prank(author);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: contentURI,
                quotedPostId: 0,
                repliedPostId: 0,
                repostedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: extraData
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify extra data was stored
        assertEq(postId, expectedPostId, "Post ID mismatch");
        assertEq(feed.getPostExtraData(postId, key), value);
    }

    function test_CannotSetExtraData_NonexistentPost() public {
        string memory contentURI = "ipfs://original";
        bytes32 key = bytes32("test.key");
        bytes memory value = abi.encode("test.value");

        // Try to edit a non-existent post with extra data
        KeyValue[] memory extraData = new KeyValue[](1);
        extraData[0] = KeyValue(key, value);

        uint256 nonExistentPostId = 123456789;

        vm.prank(author);
        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.editPost({
            postId: nonExistentPostId,
            postParams: EditPostParams(contentURI, extraData),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotSetExtraData_DifferentSender() public {
        string memory contentURI = "ipfs://original";
        bytes32 key = bytes32("test.key");
        bytes memory value = abi.encode("test.value");

        // Create post as author
        vm.prank(author);
        uint256 postId = feed.createPost({
            postParams: _getCreatePostParams(contentURI, author),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to edit post with extra data as different sender
        KeyValue[] memory extraData = new KeyValue[](1);
        extraData[0] = KeyValue(key, value);

        address differentSender = makeAddr("DIFFERENT_SENDER");
        vm.prank(differentSender);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams(contentURI, extraData),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CreatePost_WithReplyAndQuote() public {
        string memory originalContentURI = "ipfs://original";
        string memory replyContentURI = "ipfs://reply";
        string memory quotedContentURI = "ipfs://quoted";

        // Create original post (will be replied to)
        vm.prank(author);
        uint256 originalPostId = feed.createPost({
            postParams: _getCreatePostParams(originalContentURI, author),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create another post (will be quoted)
        vm.prank(author);
        uint256 quotedPostId = feed.createPost({
            postParams: _getCreatePostParams(quotedContentURI, author),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create reply post that also quotes another post
        vm.prank(author);
        uint256 replyPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: replyContentURI,
                quotedPostId: quotedPostId,
                repliedPostId: originalPostId,
                repostedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Get all posts
        Post memory originalPost = feed.getPost(originalPostId);
        Post memory quotedPost = feed.getPost(quotedPostId);
        Post memory replyPost = feed.getPost(replyPostId);

        // Verify reply post inherits root from replied post
        assertEq(replyPost.rootPostId, originalPostId, "Reply post should inherit root from replied post");
        assertEq(replyPost.repliedPostId, originalPostId, "Reply post should reference original post as replied");
        assertEq(replyPost.quotedPostId, quotedPostId, "Reply post should reference quoted post");
        assertEq(replyPost.repostedPostId, 0, "Reply post should not have reposted post ID");

        // Verify original post remains unchanged
        assertEq(originalPost.rootPostId, originalPostId, "Original post should remain its own root");
        assertEq(originalPost.quotedPostId, 0, "Original post should not have quoted post ID");
        assertEq(originalPost.repliedPostId, 0, "Original post should not have replied post ID");
        assertEq(originalPost.repostedPostId, 0, "Original post should not have reposted post ID");

        // Verify quoted post remains unchanged
        assertEq(quotedPost.rootPostId, quotedPostId, "Quoted post should remain its own root");
        assertEq(quotedPost.quotedPostId, 0, "Quoted post should not have quoted post ID");
        assertEq(quotedPost.repliedPostId, 0, "Quoted post should not have replied post ID");
        assertEq(quotedPost.repostedPostId, 0, "Quoted post should not have reposted post ID");
    }

    function test_CannotCreatePost_WithRepostAndQuote() public {
        string memory originalContentURI = "ipfs://original";
        string memory quotedContentURI = "ipfs://quoted";

        // Create original post (will be reposted)
        vm.prank(author);
        uint256 originalPostId = feed.createPost({
            postParams: _getCreatePostParams(originalContentURI, author),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create another post (will be quoted)
        vm.prank(author);
        uint256 quotedPostId = feed.createPost({
            postParams: _getCreatePostParams(quotedContentURI, author),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to create a post that is both a repost and a quote (should fail)
        vm.prank(author);
        vm.expectRevert(Errors.InvalidParameter.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: "", // Repost has empty content URI
                quotedPostId: quotedPostId,
                repliedPostId: 0,
                repostedPostId: originalPostId, // Cannot have both repostedPostId and quotedPostId
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotAddRules_ToReplyPost() public {
        string memory originalContentURI = "ipfs://original";
        string memory replyContentURI = "ipfs://reply";

        // Create original post first
        vm.prank(author);
        uint256 originalPostId = feed.createPost({
            postParams: _getCreatePostParams(originalContentURI, author),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Prepare rule changes
        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processCreatePost.selector, isRequired: true, enabled: true});

        // Try to create a reply post with rules (should fail)
        vm.prank(author);
        vm.expectRevert(Errors.CannotHaveRules.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: replyContentURI,
                quotedPostId: 0,
                repliedPostId: originalPostId,
                repostedPostId: 0,
                ruleChanges: ruleChanges, // Trying to add rules to a reply post
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotAddRules_ToReplyWithQuote() public {
        string memory originalContentURI = "ipfs://original";
        string memory quotedContentURI = "ipfs://quoted";
        string memory replyContentURI = "ipfs://reply";

        // Create original post (will be replied to)
        vm.prank(author);
        uint256 originalPostId = feed.createPost({
            postParams: _getCreatePostParams(originalContentURI, author),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create another post (will be quoted)
        vm.prank(author);
        uint256 quotedPostId = feed.createPost({
            postParams: _getCreatePostParams(quotedContentURI, author),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Prepare rule changes
        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processCreatePost.selector, isRequired: true, enabled: true});

        // Try to create a reply post with quote and rules (should fail)
        vm.prank(author);
        vm.expectRevert(Errors.CannotHaveRules.selector);
        feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: replyContentURI,
                quotedPostId: quotedPostId,
                repliedPostId: originalPostId,
                repostedPostId: 0,
                ruleChanges: ruleChanges, // Trying to add rules to a reply post with quote
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_EditQuote_ShouldProcessQuotedPostRules() public {
        string memory originalContentURI = "ipfs://original";
        string memory quoteContentURI = "ipfs://quote";
        string memory newQuoteContentURI = "ipfs://quote_edited";

        // Create original post with a mock rule
        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processEditPost.selector, isRequired: true, enabled: true});

        vm.prank(author);
        uint256 originalPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: originalContentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: ruleChanges,
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create quote post
        vm.prank(author);
        uint256 quotePostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: quoteContentURI,
                repostedPostId: 0,
                quotedPostId: originalPostId,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Prepare for edit
        EditPostParams memory editParams =
            EditPostParams({contentURI: newQuoteContentURI, extraData: _emptyKeyValueArray()});

        vm.expectCall(
            address(rule),
            abi.encodeCall(
                IPostRule.processEditPost,
                (
                    bytes32(uint256(1)),
                    originalPostId,
                    quotePostId,
                    editParams,
                    _emptyKeyValueArray(),
                    _emptyKeyValueArray()
                )
            )
        );

        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_PostEdited(
            quotePostId,
            author,
            editParams,
            _emptyKeyValueArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            address(0)
        );

        // Edit the quote post
        vm.prank(author);
        feed.editPost({
            postId: quotePostId,
            postParams: editParams,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify post relationships remain intact
        Post memory quotePost = feed.getPost(quotePostId);
        assertEq(quotePost.quotedPostId, originalPostId, "Quoted post ID should remain unchanged");
        assertEq(quotePost.contentURI, newQuoteContentURI, "Content URI should be updated");
        assertEq(quotePost.rootPostId, quotePostId, "Root post ID should be self for quote");
        assertEq(quotePost.repliedPostId, 0, "Reply post ID should remain 0");
        assertEq(quotePost.repostedPostId, 0, "Repost post ID should remain 0");
    }

    function test_EditReply_ShouldProcessRootPostRules() public {
        string memory originalContentURI = "ipfs://original";
        string memory replyContentURI = "ipfs://reply";
        string memory newReplyContentURI = "ipfs://reply_edited";

        // Create original post with a mock rule
        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processEditPost.selector, isRequired: true, enabled: true});

        vm.prank(author);
        uint256 originalPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: originalContentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: ruleChanges,
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create reply post
        vm.prank(author);
        uint256 replyPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: replyContentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: originalPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Prepare for edit
        EditPostParams memory editParams =
            EditPostParams({contentURI: newReplyContentURI, extraData: _emptyKeyValueArray()});

        vm.expectCall(
            address(rule),
            abi.encodeCall(
                IPostRule.processEditPost,
                (
                    bytes32(uint256(1)),
                    originalPostId,
                    replyPostId,
                    editParams,
                    _emptyKeyValueArray(),
                    _emptyKeyValueArray()
                )
            )
        );

        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_PostEdited(
            replyPostId,
            author,
            editParams,
            _emptyKeyValueArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            address(0)
        );

        // Edit the reply post
        vm.prank(author);
        feed.editPost({
            postId: replyPostId,
            postParams: editParams,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify post relationships remain intact
        Post memory replyPost = feed.getPost(replyPostId);
        assertEq(replyPost.repliedPostId, originalPostId, "Replied post ID should remain unchanged");
        assertEq(replyPost.contentURI, newReplyContentURI, "Content URI should be updated");
        assertEq(replyPost.rootPostId, originalPostId, "Root post ID should be original post");
        assertEq(replyPost.quotedPostId, 0, "Quote post ID should remain 0");
        assertEq(replyPost.repostedPostId, 0, "Repost post ID should remain 0");
    }

    function test_EditReplyWithQuote_ShouldProcessBothRules() public {
        string memory rootContentURI = "ipfs://root";
        string memory quotedContentURI = "ipfs://quoted";
        string memory replyContentURI = "ipfs://reply";
        string memory newReplyContentURI = "ipfs://reply_edited";

        // Create root post with a mock rule
        RuleChange[] memory rootRuleChanges = new RuleChange[](1);
        rootRuleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        rootRuleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processEditPost.selector, isRequired: true, enabled: true});

        vm.prank(author);
        uint256 rootPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: rootContentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: rootRuleChanges,
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create quoted post with a different mock rule
        MockRule quotedRule = new MockRule();
        RuleChange[] memory quotedRuleChanges = new RuleChange[](1);
        quotedRuleChanges[0] = RuleChange({
            ruleAddress: address(quotedRule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        quotedRuleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processEditPost.selector, isRequired: true, enabled: true});

        vm.prank(author);
        uint256 quotedPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: quotedContentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: quotedRuleChanges,
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create reply post that also quotes another post
        vm.prank(author);
        uint256 replyPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: replyContentURI,
                repostedPostId: 0,
                quotedPostId: quotedPostId,
                repliedPostId: rootPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Prepare for edit
        EditPostParams memory editParams =
            EditPostParams({contentURI: newReplyContentURI, extraData: _emptyKeyValueArray()});

        // Expect both rules to be called
        vm.expectCall(
            address(rule),
            abi.encodeCall(
                IPostRule.processEditPost,
                (bytes32(uint256(1)), rootPostId, replyPostId, editParams, _emptyKeyValueArray(), _emptyKeyValueArray())
            )
        );

        vm.expectCall(
            address(quotedRule),
            abi.encodeCall(
                IPostRule.processEditPost,
                (
                    bytes32(uint256(1)),
                    quotedPostId,
                    replyPostId,
                    editParams,
                    _emptyKeyValueArray(),
                    _emptyKeyValueArray()
                )
            )
        );

        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_PostEdited(
            replyPostId,
            author,
            editParams,
            _emptyKeyValueArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            address(0)
        );

        // Edit the reply post
        vm.prank(author);
        feed.editPost({
            postId: replyPostId,
            postParams: editParams,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify post relationships remain intact
        Post memory replyPost = feed.getPost(replyPostId);
        assertEq(replyPost.repliedPostId, rootPostId, "Replied post ID should remain unchanged");
        assertEq(replyPost.quotedPostId, quotedPostId, "Quoted post ID should remain unchanged");
        assertEq(replyPost.contentURI, newReplyContentURI, "Content URI should be updated");
        assertEq(replyPost.rootPostId, rootPostId, "Root post ID should be root post");
        assertEq(replyPost.repostedPostId, 0, "Repost post ID should remain 0");
    }

    function test_EditQuoteChain_ShouldProcessQuotedPostRules() public {
        string memory firstContentURI = "ipfs://first";
        string memory secondContentURI = "ipfs://second";
        string memory thirdContentURI = "ipfs://third";
        string memory newThirdContentURI = "ipfs://third_edited";

        // Create first post with a mock rule
        RuleChange[] memory firstRuleChanges = new RuleChange[](1);
        firstRuleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        firstRuleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processEditPost.selector, isRequired: true, enabled: true});

        vm.prank(author);
        uint256 firstPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: firstContentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: firstRuleChanges,
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create second post with a different mock rule
        MockRule secondRule = new MockRule();
        RuleChange[] memory secondRuleChanges = new RuleChange[](1);
        secondRuleChanges[0] = RuleChange({
            ruleAddress: address(secondRule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        secondRuleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processEditPost.selector, isRequired: true, enabled: true});

        vm.prank(author);
        uint256 secondPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: secondContentURI,
                repostedPostId: 0,
                quotedPostId: firstPostId,
                repliedPostId: 0,
                ruleChanges: secondRuleChanges,
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create third post quoting the second post
        vm.prank(author);
        uint256 thirdPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: thirdContentURI,
                repostedPostId: 0,
                quotedPostId: secondPostId,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Prepare for edit
        EditPostParams memory editParams =
            EditPostParams({contentURI: newThirdContentURI, extraData: _emptyKeyValueArray()});

        // Expect only the second post's rule to be called since it's the directly quoted post
        vm.expectCall(
            address(secondRule),
            abi.encodeCall(
                IPostRule.processEditPost,
                (
                    bytes32(uint256(1)),
                    secondPostId,
                    thirdPostId,
                    editParams,
                    _emptyKeyValueArray(),
                    _emptyKeyValueArray()
                )
            )
        );

        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_PostEdited(
            thirdPostId,
            author,
            editParams,
            _emptyKeyValueArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            address(0)
        );

        // Edit the third post
        vm.prank(author);
        feed.editPost({
            postId: thirdPostId,
            postParams: editParams,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify post relationships remain intact
        Post memory thirdPost = feed.getPost(thirdPostId);
        assertEq(thirdPost.quotedPostId, secondPostId, "Quoted post ID should remain unchanged");
        assertEq(thirdPost.contentURI, newThirdContentURI, "Content URI should be updated");
        assertEq(thirdPost.rootPostId, thirdPostId, "Root post ID should be self for quote");
        assertEq(thirdPost.repliedPostId, 0, "Reply post ID should remain 0");
        assertEq(thirdPost.repostedPostId, 0, "Repost post ID should remain 0");
    }

    function test_EditReplyChain_ShouldProcessRootRules() public {
        string memory rootContentURI = "ipfs://root";
        string memory firstReplyContentURI = "ipfs://first_reply";
        string memory secondReplyContentURI = "ipfs://second_reply";
        string memory newSecondReplyContentURI = "ipfs://second_reply_edited";

        // Create root post with a mock rule
        RuleChange[] memory rootRuleChanges = new RuleChange[](1);
        rootRuleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        rootRuleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processEditPost.selector, isRequired: true, enabled: true});

        vm.prank(author);
        uint256 rootPostId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: rootContentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: rootRuleChanges,
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create first reply post
        vm.prank(author);
        uint256 firstReplyId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: firstReplyContentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: rootPostId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create second reply post (replying to first reply)
        vm.prank(author);
        uint256 secondReplyId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: secondReplyContentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: firstReplyId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Prepare for edit
        EditPostParams memory editParams =
            EditPostParams({contentURI: newSecondReplyContentURI, extraData: _emptyKeyValueArray()});

        // Expect root post's rule to be called
        vm.expectCall(
            address(rule),
            abi.encodeCall(
                IPostRule.processEditPost,
                (
                    bytes32(uint256(1)),
                    rootPostId,
                    secondReplyId,
                    editParams,
                    _emptyKeyValueArray(),
                    _emptyKeyValueArray()
                )
            )
        );

        vm.expectEmit(true, true, true, true);
        emit IFeed.Lens_Feed_PostEdited(
            secondReplyId,
            author,
            editParams,
            _emptyKeyValueArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyRuleProcessingParamsArray(),
            address(0)
        );

        // Edit the second reply post
        vm.prank(author);
        feed.editPost({
            postId: secondReplyId,
            postParams: editParams,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify post relationships remain intact
        Post memory secondReply = feed.getPost(secondReplyId);
        assertEq(secondReply.repliedPostId, firstReplyId, "Replied post ID should remain unchanged");
        assertEq(secondReply.contentURI, newSecondReplyContentURI, "Content URI should be updated");
        assertEq(secondReply.rootPostId, rootPostId, "Root post ID should be root post");
        assertEq(secondReply.quotedPostId, 0, "Quote post ID should remain 0");
        assertEq(secondReply.repostedPostId, 0, "Repost post ID should remain 0");
    }

    function test_CannotGetAuthorPostSequentialId_ForNonExistentPost(uint256 nonExistentPostId) public {
        // Try to get authorPostSequentialId for a non-existent post
        vm.assume(feed.postExists(nonExistentPostId) == false);
        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.getAuthorPostSequentialId(nonExistentPostId);
    }

    function test_CannotChangePostRules_IfNotAuthor(address nonAuthor) public {
        vm.assume(nonAuthor != address(0));
        vm.assume(nonAuthor != author);

        // Create original post with rules
        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule),
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processEditPost.selector, isRequired: true, enabled: true});

        vm.prank(author);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: "original content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: ruleChanges,
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to change rules as non-author
        vm.prank(nonAuthor);
        vm.expectRevert(Errors.InvalidMsgSender.selector);

        feed.changePostRules({
            postId: postId,
            ruleChanges: ruleChanges,
            feedRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override(RulesTest, RuleExecutionTest) {
        IFeed(feedForRules).changeFeedRules(ruleChanges);
    }

    function _primitiveAddress() internal view override returns (address) {
        return feedForRules;
    }

    function _aValidRuleSelector() internal pure override returns (bytes4) {
        return IFeedRule.processCreatePost.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IFeedRule.processCreatePost.selector;
        selectors[1] = IFeedRule.processEditPost.selector;
        selectors[2] = IFeedRule.processDeletePost.selector;
        selectors[3] = IFeedRule.processPostRuleChanges.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return IFeed(feedForRules).getFeedRules(selector, required);
    }

    function _configureRuleSelector() internal pure override(RulesTest, RuleExecutionTest) returns (bytes4) {
        return IFeedRule.configure.selector;
    }

    function _generatePostId(address _feed, address _author, uint256 _authorPostSequentialId)
        internal
        view
        returns (uint256)
    {
        return uint256(keccak256(abi.encode("evm:", block.chainid, address(_feed), _author, _authorPostSequentialId)));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testRuleExecution_CreatePost(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = IFeedRule.processCreatePost.selector;

        string memory contentURI = "ipfs://content";

        CreatePostParams memory postParams = CreatePostParams({
            author: address(this),
            contentURI: contentURI,
            repostedPostId: 0,
            quotedPostId: 0,
            repliedPostId: 0,
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        bytes memory executionFunctionCallData = abi.encodeCall(
            IFeed.createPost,
            (
                postParams,
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray()
            )
        );

        uint256 expectedPostId = _generatePostId(address(feedForRules), address(this), 1);

        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IFeedRule.processCreatePost,
            (bytes32(uint256(1)), expectedPostId, postParams, _emptyKeyValueArray(), _emptyKeyValueArray())
        );

        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(feedForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_EditPost(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = IFeedRule.processEditPost.selector;
        uint256 postId;

        {
            CreatePostParams memory postParams = CreatePostParams({
                author: address(this),
                contentURI: "ipfs://content",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            });

            postId = IFeed(feedForRules).createPost(
                postParams,
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray()
            );
        }

        EditPostParams memory editParams =
            EditPostParams({contentURI: "ipfs://content_edited", extraData: _emptyKeyValueArray()});

        bytes memory executionFunctionCallData = abi.encodeCall(
            IFeed.editPost,
            (
                postId,
                editParams,
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray()
            )
        );

        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IFeedRule.processEditPost,
            (bytes32(uint256(1)), postId, editParams, _emptyKeyValueArray(), _emptyKeyValueArray())
        );

        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(feedForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_DeletePost(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = IFeedRule.processDeletePost.selector;
        uint256 postId;

        {
            CreatePostParams memory postParams = CreatePostParams({
                author: address(this),
                contentURI: "ipfs://content",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            });

            postId = IFeed(feedForRules).createPost(
                postParams,
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray()
            );
        }

        bytes memory executionFunctionCallData =
            abi.encodeCall(IFeed.deletePost, (postId, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray()));

        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IFeedRule.processDeletePost, (bytes32(uint256(1)), postId, _emptyKeyValueArray(), _emptyKeyValueArray())
        );

        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(feedForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_PostRuleChanges(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        uint256 postId;

        {
            CreatePostParams memory postParams = CreatePostParams({
                author: address(this),
                contentURI: "ipfs://content",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            });

            postId = IFeed(feedForRules).createPost(
                postParams,
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray()
            );
        }

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: address(rule1),
            configSalt: bytes32(uint256(0)),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: new RuleSelectorChange[](1)
        });
        ruleChanges[0].selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IPostRule.processCreatePost.selector, isRequired: true, enabled: true});

        bytes4 executionSelector = IFeedRule.processPostRuleChanges.selector;

        bytes memory executionFunctionCallData =
            abi.encodeCall(IFeed.changePostRules, (postId, ruleChanges, _emptyRuleProcessingParamsArray()));

        RuleChange[] memory expectedRuleChanges = new RuleChange[](1);
        expectedRuleChanges[0] = ruleChanges[0];
        expectedRuleChanges[0].configSalt = bytes32(uint256(1));

        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IFeedRule.processPostRuleChanges, (bytes32(uint256(1)), postId, expectedRuleChanges, _emptyKeyValueArray())
        );

        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(feedForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }
}

contract FeedTest3 is RulesTest, BaseDeployments, RuleExecutionTest {
    IFeed feed;

    address feedForRules;
    MockAccessControl mockAccessControl;

    address author = makeAddr("AUTHOR");
    address feedOwner = makeAddr("FEED_OWNER");

    function setUp() public virtual override(RulesTest, BaseDeployments, RuleExecutionTest) {
        BaseDeployments.setUp();

        mockAccessControl = new MockAccessControl();

        vm.prank(address(lensFactory));
        feed = IFeed(
            feedFactory.deployFeed({
                metadataURI: "some metadata uri",
                accessControl: mockAccessControl,
                proxyAdminOwner: address(this),
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        vm.prank(address(lensFactory));
        feedForRules = feedFactory.deployFeed({
            metadataURI: "uri://feed",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        RulesTest.setUp();
        RuleExecutionTest.setUp();
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override(RulesTest, RuleExecutionTest) {
        IFeed(feedForRules).changeFeedRules(ruleChanges);
    }

    function _primitiveAddress() internal view override returns (address) {
        return feedForRules;
    }

    function _aValidRuleSelector() internal pure override returns (bytes4) {
        return IFeedRule.processCreatePost.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IFeedRule.processCreatePost.selector;
        selectors[1] = IFeedRule.processEditPost.selector;
        selectors[2] = IFeedRule.processDeletePost.selector;
        selectors[3] = IFeedRule.processPostRuleChanges.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return IFeed(feedForRules).getFeedRules(selector, required);
    }

    function _configureRuleSelector() internal pure override(RulesTest, RuleExecutionTest) returns (bytes4) {
        return IFeedRule.configure.selector;
    }

    function _generatePostId(address _feed, address _author, uint256 _authorPostSequentialId)
        internal
        view
        returns (uint256)
    {
        return uint256(keccak256(abi.encode("evm:", block.chainid, address(_feed), _author, _authorPostSequentialId)));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_CannotDeletePost_NonexistentPost(address postAuthor, uint256 nonexistentPostId) public {
        vm.assume(postAuthor != address(0));
        vm.assume(nonexistentPostId != 0);
        vm.assume(!feed.postExists(nonexistentPostId));

        // Try to delete a nonexistent post
        vm.prank(postAuthor);
        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.deletePost({
            postId: nonexistentPostId,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotDeletePost_IfAlreadyDeleted(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        // Create a post
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "ipfs://QmTest",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Delete the post
        vm.prank(postAuthor);
        feed.deletePost({
            postId: postId,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Try to delete the post again
        vm.prank(postAuthor);
        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.deletePost({
            postId: postId,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_DeletedPost_NotAccessible(address postAuthor, uint256 deletedPostId) public {
        vm.assume(postAuthor != address(0));
        vm.assume(deletedPostId != 0);
        vm.assume(!feed.postExists(deletedPostId));

        // Try to get the deleted post
        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.getPost(deletedPostId);
    }

    function test_PostId_Generation(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        // Get the expected post IDs before creating posts
        uint256 expectedFirstPostId = feed.getNextPostId(postAuthor);

        // Create multiple posts from the same author
        vm.startPrank(postAuthor);

        uint256 firstPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "first post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        uint256 expectedSecondPostId = feed.getNextPostId(postAuthor);

        uint256 secondPostId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "second post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        vm.stopPrank();

        // Verify that the post IDs match what we expected
        assertEq(firstPostId, expectedFirstPostId, "First post ID should match expected");
        assertEq(secondPostId, expectedSecondPostId, "Second post ID should match expected");

        // Verify that post IDs are different
        assertTrue(firstPostId != secondPostId, "Post IDs should be unique");

        // Verify author post sequential IDs
        assertEq(feed.getAuthorPostSequentialId(firstPostId), 1, "First post should have authorPostSequentialId = 1");
        assertEq(feed.getAuthorPostSequentialId(secondPostId), 2, "Second post should have authorPostSequentialId = 2");

        // Create a post from a different author to verify post IDs are author-specific
        address differentAuthor = makeAddr("DIFFERENT_AUTHOR");
        uint256 expectedDifferentAuthorPostId = feed.getNextPostId(differentAuthor);

        vm.prank(differentAuthor);
        uint256 differentAuthorPostId = feed.createPost({
            postParams: CreatePostParams({
                author: differentAuthor,
                contentURI: "different author post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify that the different author's post ID matches what we expected
        assertEq(differentAuthorPostId, expectedDifferentAuthorPostId, "Different author post ID should match expected");

        // Verify that post IDs from different authors are different
        assertTrue(firstPostId != differentAuthorPostId, "Post IDs should be unique across authors");
        assertTrue(secondPostId != differentAuthorPostId, "Post IDs should be unique across authors");

        // Verify different author's post sequential ID starts at 1
        assertEq(
            feed.getAuthorPostSequentialId(differentAuthorPostId),
            1,
            "Different author's first post should have authorPostSequentialId = 1"
        );
    }

    function test_PostSequentialId_Uniqueness(address firstAuthor, address secondAuthor) public {
        vm.assume(firstAuthor != address(0));
        vm.assume(secondAuthor != address(0));
        vm.assume(firstAuthor != secondAuthor);

        // Get initial post count
        uint256 initialPostCount = feed.getPostCount();

        // Create first post
        vm.prank(firstAuthor);
        uint256 firstPostId = feed.createPost({
            postParams: CreatePostParams({
                author: firstAuthor,
                contentURI: "first post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create second post
        vm.prank(secondAuthor);
        uint256 secondPostId = feed.createPost({
            postParams: CreatePostParams({
                author: secondAuthor,
                contentURI: "second post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify sequential IDs
        Post memory firstPost = feed.getPost(firstPostId);
        Post memory secondPost = feed.getPost(secondPostId);

        assertEq(firstPost.postSequentialId, initialPostCount + 1, "First post should have sequential ID 1");
        assertEq(secondPost.postSequentialId, initialPostCount + 2, "Second post should have sequential ID 2");

        assertEq(feed.getPostSequentialId(firstPostId), initialPostCount + 1, "First post sequential ID should match");
        assertEq(feed.getPostSequentialId(secondPostId), initialPostCount + 2, "Second post sequential ID should match");

        // Verify global post count increased correctly
        assertEq(feed.getPostCount(), initialPostCount + 2, "Global post count should increase by 2");
    }

    function test_AuthorPostSequentialId_Uniqueness(address firstAuthor, address secondAuthor) public {
        vm.assume(firstAuthor != address(0));
        vm.assume(secondAuthor != address(0));
        vm.assume(firstAuthor != secondAuthor);

        // Get initial author post counts
        uint256 initialFirstAuthorCount = feed.getPostCount(firstAuthor);
        uint256 initialSecondAuthorCount = feed.getPostCount(secondAuthor);

        // Create two posts from first author
        vm.startPrank(firstAuthor);
        uint256 firstAuthorPostId1 = feed.createPost({
            postParams: CreatePostParams({
                author: firstAuthor,
                contentURI: "first author post 1",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        uint256 firstAuthorPostId2 = feed.createPost({
            postParams: CreatePostParams({
                author: firstAuthor,
                contentURI: "first author post 2",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
        vm.stopPrank();

        // Create a post from second author
        vm.prank(secondAuthor);
        uint256 secondAuthorPostId = feed.createPost({
            postParams: CreatePostParams({
                author: secondAuthor,
                contentURI: "second author post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify sequential IDs for first author's posts
        Post memory firstAuthorPost1 = feed.getPost(firstAuthorPostId1);
        Post memory firstAuthorPost2 = feed.getPost(firstAuthorPostId2);

        assertEq(
            firstAuthorPost1.authorPostSequentialId,
            initialFirstAuthorCount + 1,
            "First author's first post should have sequential ID 1"
        );
        assertEq(
            firstAuthorPost2.authorPostSequentialId,
            initialFirstAuthorCount + 2,
            "First author's second post should have sequential ID 2"
        );
        assertTrue(
            firstAuthorPost1.authorPostSequentialId != firstAuthorPost2.authorPostSequentialId,
            "Author post sequential IDs should be unique"
        );

        // Verify sequential ID for second author's post
        Post memory secondAuthorPost = feed.getPost(secondAuthorPostId);
        assertEq(
            secondAuthorPost.authorPostSequentialId,
            initialSecondAuthorCount + 1,
            "Second author's post should have sequential ID 1"
        );

        // Verify author post counts increased correctly
        assertEq(
            feed.getPostCount(firstAuthor), initialFirstAuthorCount + 2, "First author's post count should increase by 2"
        );
        assertEq(
            feed.getPostCount(secondAuthor),
            initialSecondAuthorCount + 1,
            "Second author's post count should increase by 1"
        );
    }

    function test_PostTimestamp_Ordering(address firstAuthor, address secondAuthor) public {
        vm.assume(firstAuthor != address(0));
        vm.assume(secondAuthor != address(0));
        vm.assume(firstAuthor != secondAuthor);

        // Create first post
        vm.prank(firstAuthor);
        uint256 firstPostId = feed.createPost({
            postParams: CreatePostParams({
                author: firstAuthor,
                contentURI: "first post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create second post in the same block
        vm.prank(secondAuthor);
        uint256 secondPostId = feed.createPost({
            postParams: CreatePostParams({
                author: secondAuthor,
                contentURI: "second post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Create third post in a future block
        vm.warp(block.timestamp + 1);
        vm.prank(firstAuthor);
        uint256 thirdPostId = feed.createPost({
            postParams: CreatePostParams({
                author: firstAuthor,
                contentURI: "third post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Get post data
        Post memory firstPost = feed.getPost(firstPostId);
        Post memory secondPost = feed.getPost(secondPostId);
        Post memory thirdPost = feed.getPost(thirdPostId);

        // Verify timestamps are unique
        assertTrue(
            firstPost.creationTimestamp != secondPost.creationTimestamp
                || firstPost.postSequentialId != secondPost.postSequentialId,
            "Posts in same block should have unique identifiers"
        );
        assertTrue(
            firstPost.creationTimestamp < thirdPost.creationTimestamp,
            "Posts in different blocks should have different timestamps"
        );
        assertTrue(
            secondPost.creationTimestamp < thirdPost.creationTimestamp,
            "Posts in different blocks should have different timestamps"
        );

        // Verify last updated timestamps match creation timestamps for new posts
        assertEq(
            firstPost.lastUpdatedTimestamp,
            firstPost.creationTimestamp,
            "Last updated should match creation for new post"
        );
        assertEq(
            secondPost.lastUpdatedTimestamp,
            secondPost.creationTimestamp,
            "Last updated should match creation for new post"
        );
        assertEq(
            thirdPost.lastUpdatedTimestamp,
            thirdPost.creationTimestamp,
            "Last updated should match creation for new post"
        );
    }

    function test_CreationTimestamp_Set(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        // Record current timestamp
        uint256 currentTimestamp = block.timestamp;

        // Create a post
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "test post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Get post data
        Post memory post = feed.getPost(postId);

        // Verify creation timestamp is set to current block timestamp
        assertEq(post.creationTimestamp, currentTimestamp, "Creation timestamp should be current block timestamp");

        // Warp to future timestamp
        vm.warp(block.timestamp + 1 hours);

        // Edit the post
        vm.prank(postAuthor);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams({contentURI: "edited post", extraData: _emptyKeyValueArray()}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Get updated post data
        Post memory editedPost = feed.getPost(postId);

        // Verify creation timestamp remains unchanged after edit
        assertEq(editedPost.creationTimestamp, currentTimestamp, "Creation timestamp should not change after edit");
    }

    function test_LastUpdatedTimestamp_Updates(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        // Create a post
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "test post",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Get post data
        Post memory post = feed.getPost(postId);

        // Verify last updated timestamp matches creation timestamp for new post
        assertEq(post.lastUpdatedTimestamp, post.creationTimestamp, "Last updated should match creation for new post");

        // Warp to future timestamp
        uint256 editTimestamp = block.timestamp + 1 hours;
        vm.warp(editTimestamp);

        // Edit the post
        vm.prank(postAuthor);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams({contentURI: "edited post", extraData: _emptyKeyValueArray()}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Get updated post data
        Post memory editedPost = feed.getPost(postId);

        // Verify last updated timestamp is updated to edit timestamp
        assertEq(editedPost.lastUpdatedTimestamp, editTimestamp, "Last updated should be edit timestamp");
        assertTrue(editedPost.lastUpdatedTimestamp > post.lastUpdatedTimestamp, "Last updated should increase");

        // Warp to another future timestamp
        uint256 secondEditTimestamp = block.timestamp + 1 hours;
        vm.warp(secondEditTimestamp);

        // Edit the post again
        vm.prank(postAuthor);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams({contentURI: "edited again", extraData: _emptyKeyValueArray()}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Get updated post data
        Post memory secondEditedPost = feed.getPost(postId);

        // Verify last updated timestamp is updated to second edit timestamp
        assertEq(
            secondEditedPost.lastUpdatedTimestamp, secondEditTimestamp, "Last updated should be second edit timestamp"
        );
        assertTrue(
            secondEditedPost.lastUpdatedTimestamp > editedPost.lastUpdatedTimestamp, "Last updated should increase"
        );
    }

    // TODO: Fill in empty arrays for all params and test with that
    function test_GetPost(address postAuthor, string memory contentURI) public {
        vm.assume(postAuthor != address(0));
        vm.assume(bytes(contentURI).length > 0);

        // Create a post first
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: contentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Get and verify the post
        Post memory post = feed.getPost(postId);

        assertEq(post.author, postAuthor, "Post author should match");
        assertEq(post.contentURI, contentURI, "Content URI should match");
        assertEq(post.postSequentialId, feed.getPostCount(), "Post sequential ID should match");
        assertEq(post.authorPostSequentialId, feed.getPostCount(postAuthor), "Author post sequential ID should match");
        assertEq(post.rootPostId, postId, "Root post ID should be self for new post");
        assertEq(post.repostedPostId, 0, "Reposted post ID should be 0");
        assertEq(post.quotedPostId, 0, "Quoted post ID should be 0");
        assertEq(post.repliedPostId, 0, "Replied post ID should be 0");
        assertEq(post.creationTimestamp, block.timestamp, "Creation timestamp should be current block");
        assertEq(post.lastUpdatedTimestamp, block.timestamp, "Last updated timestamp should be current block");
        assertEq(post.creationSource, address(0), "Creation source should be 0 address");
        assertEq(post.lastUpdateSource, address(0), "Last update source should be 0 address");
    }

    function test_GetPostAuthor(address postAuthor, string memory contentURI) public {
        vm.assume(postAuthor != address(0));
        vm.assume(bytes(contentURI).length > 0);

        // Create a post first
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: contentURI,
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        assertEq(feed.getPostAuthor(postId), postAuthor, "Post author should match");
    }

    function test_GetPostAuthor_NonexistentPost(uint256 nonexistentPostId) public {
        vm.assume(!feed.postExists(nonexistentPostId));

        vm.expectRevert(Errors.DoesNotExist.selector);
        feed.getPostAuthor(nonexistentPostId);
    }

    function test_GetPostCount_Global(address postAuthor, uint8 numberOfPosts) public {
        vm.assume(postAuthor != address(0));
        numberOfPosts = uint8(bound(numberOfPosts, 1, 10));

        uint256 startingPostCount = feed.getPostCount();

        for (uint256 i = 0; i < numberOfPosts; i++) {
            vm.prank(postAuthor);
            feed.createPost({
                postParams: CreatePostParams({
                    author: postAuthor,
                    contentURI: string.concat("content://", vm.toString(i)),
                    repostedPostId: 0,
                    quotedPostId: 0,
                    repliedPostId: 0,
                    ruleChanges: _emptyRuleChangeArray(),
                    extraData: _emptyKeyValueArray()
                }),
                customParams: _emptyKeyValueArray(),
                feedRulesParams: _emptyRuleProcessingParamsArray(),
                rootPostRulesParams: _emptyRuleProcessingParamsArray(),
                quotedPostRulesParams: _emptyRuleProcessingParamsArray()
            });
            assertEq(feed.getPostCount(), startingPostCount + i + 1, "Global post count should increment");
        }
    }

    function test_GetPostCount_PerAuthor() public {
        // Create multiple authors with different post counts
        address[] memory authors = new address[](3);
        uint8[] memory postCounts = new uint8[](3);

        authors[0] = makeAddr("AUTHOR1");
        authors[1] = makeAddr("AUTHOR2");
        authors[2] = makeAddr("AUTHOR3");

        postCounts[0] = 3;
        postCounts[1] = 1;
        postCounts[2] = 2;

        for (uint256 i = 0; i < authors.length; i++) {
            for (uint256 j = 0; j < postCounts[i]; j++) {
                vm.prank(authors[i]);
                feed.createPost({
                    postParams: CreatePostParams({
                        author: authors[i],
                        contentURI: string.concat("content://", vm.toString(j)),
                        repostedPostId: 0,
                        quotedPostId: 0,
                        repliedPostId: 0,
                        ruleChanges: _emptyRuleChangeArray(),
                        extraData: _emptyKeyValueArray()
                    }),
                    customParams: _emptyKeyValueArray(),
                    feedRulesParams: _emptyRuleProcessingParamsArray(),
                    rootPostRulesParams: _emptyRuleProcessingParamsArray(),
                    quotedPostRulesParams: _emptyRuleProcessingParamsArray()
                });
            }
            assertEq(feed.getPostCount(authors[i]), postCounts[i], "Author post count should match");
        }

        // Verify total post count
        assertEq(feed.getPostCount(), 6, "Global post count should match sum of all authors' posts");
    }

    function test_GetNextPostId(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        uint256 expectedNextPostId = feed.getNextPostId(postAuthor);

        // Create a post
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "some content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify the post ID matches what was predicted
        assertEq(postId, expectedNextPostId, "Post ID should match predicted next ID");

        // Verify next post ID is different
        uint256 newNextPostId = feed.getNextPostId(postAuthor);
        assertTrue(newNextPostId != postId, "New next post ID should be different");
    }

    function test_PostExists(address postAuthor) public {
        vm.assume(postAuthor != address(0));

        // Create a post
        vm.prank(postAuthor);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: postAuthor,
                contentURI: "some content uri",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify post exists
        assertTrue(feed.postExists(postId), "Post should exist after creation");

        // Delete the post
        vm.prank(postAuthor);
        feed.deletePost({
            postId: postId,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray()
        });

        // Verify post no longer exists
        assertFalse(feed.postExists(postId), "Post should not exist after deletion");

        // Verify a random post ID does not exist
        uint256 randomPostId = uint256(keccak256(abi.encodePacked("nonexistent")));
        assertFalse(feed.postExists(randomPostId), "Random post ID should not exist");
    }

    function test_SetMetadataURI_HasPID(address addressWithPID) public {
        string memory newMetadataURI = "uri://new-metadata-uri";
        assertNotEq(IMetadataBased(address(feed)).getMetadataURI(), newMetadataURI);
        mockAccessControl.mockAccess(
            addressWithPID, address(feed), uint256(keccak256("lens.permission.SetMetadata")), true
        );
        vm.prank(addressWithPID);
        IMetadataBased(address(feed)).setMetadataURI(newMetadataURI);
        assertEq(IMetadataBased(address(feed)).getMetadataURI(), newMetadataURI);
    }

    function test_Cannot_SetMetadataURI_IfDoesNotHavePID(address addressWithoutPID) public {
        string memory oldMetadataURI = IMetadataBased(address(feed)).getMetadataURI();
        string memory newMetadataURI = "uri://new-metadata-uri";
        assertNotEq(oldMetadataURI, newMetadataURI);
        mockAccessControl.mockAccess(
            addressWithoutPID, address(feed), uint256(keccak256("lens.permission.SetMetadata")), false
        );
        vm.prank(addressWithoutPID);
        vm.expectRevert(Errors.AccessDenied.selector);
        IMetadataBased(address(feed)).setMetadataURI(newMetadataURI);
        assertEq(IMetadataBased(address(feed)).getMetadataURI(), oldMetadataURI);
    }
}
