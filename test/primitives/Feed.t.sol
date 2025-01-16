// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "@extensions/access/OwnerAdminOnlyAccessControl.sol";
import "../helpers/TypeHelpers.sol";
import {Feed} from "@core/primitives/feed/Feed.sol";
import {IFeed, CreatePostParams, EditPostParams, Post} from "@core/interfaces/IFeed.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {IFeedRule} from "@core/interfaces/IFeedRule.sol";
import {Rule, RuleChange, RuleConfigurationChange, RuleSelectorChange} from "@core/types/Types.sol";
import {Errors} from "@core/types/Errors.sol";

contract FeedTest is RulesTest, BaseDeployments {
    IFeed feed;

    address feedForRules;
    MockAccessControl mockAccessControl;

    address author = makeAddr("AUTHOR");
    address feedOwner = makeAddr("FEED_OWNER");

    function setUp() public virtual override(RulesTest, BaseDeployments) {
        BaseDeployments.setUp();

        mockAccessControl = new MockAccessControl();

        feed = IFeed(
            feedFactory.deployFeed({
                metadataURI: "some metadata uri",
                accessControl: mockAccessControl,
                proxyAdminOwner: address(this),
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        // Ensure no one has the REMOVE_POST permission
        // PID__REMOVE_POST = keccak256("lens.permission.RemovePost")
        mockAccessControl.mockAccess(
            address(0), address(feed), uint256(0x25b86c749bcf827bec85b3f107e1d65771462eb329e68ff158d50a2f4b301c89), false
        );

        feedForRules = feedFactory.deployFeed({
            metadataURI: "uri://feed",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        RulesTest.setUp();
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
            RuleSelectorChange({ruleSelector: IFeedRule.processCreatePost.selector, isRequired: true, enabled: true});

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

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override {
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
        selectors[2] = IFeedRule.processRemovePost.selector;
        selectors[3] = IFeedRule.processPostRuleChanges.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return IFeed(feedForRules).getFeedRules(selector, required);
    }
}
