// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// Import the necessary contracts and interfaces
import {Feed, DataElementValue} from "contracts/primitives/feed/Feed.sol";
import {FeedFactory} from "contracts/factories/FeedFactory.sol";
import {OwnerOnlyAccessControl} from "contracts/primitives/access-control/OwnerOnlyAccessControl.sol";
import {IAccessControl} from "contracts/primitives/access-control/IAccessControl.sol";
import {
    CreatePostParams,
    CreateRepostParams,
    EditPostParams,
    Post,
    RuleConfiguration,
    RuleExecutionData
} from "contracts/primitives/feed/IFeed.sol";

import {RuleConfiguration, DataElement} from "contracts/types/Types.sol";

// Import the mock rule contracts
import {MockFeedRule} from "../../mocks/MockFeedRule.sol";
import {MockPostRule} from "../../mocks/MockPostRule.sol";

contract FeedTest is Test {
    Feed feed;
    FeedFactory feedFactory;
    OwnerOnlyAccessControl accessControl;

    MockFeedRule mockFeedRule;
    MockPostRule mockPostRule;

    MockFeedRule mockFeedRule2;
    MockPostRule mockPostRule2;

    address owner = makeAddr("Owner");
    address user = makeAddr("User");
    address otherUser = makeAddr("OtherUser");

    function setUp() public {
        vm.label(owner, "Owner");
        vm.label(user, "User");

        vm.deal(owner, 10 ether);
        vm.deal(user, 10 ether);

        // Deploy the AccessControl contract with the owner
        vm.startPrank(owner);
        accessControl = new OwnerOnlyAccessControl(owner);
        vm.stopPrank();

        // Deploy the FeedFactory contract
        vm.startPrank(owner);
        feedFactory = new FeedFactory();
        vm.stopPrank();

        // Prepare the parameters for deploying the Feed contract
        string memory metadataURI = "Initial Metadata URI";
        RuleConfiguration[] memory rules = new RuleConfiguration[](0); // No initial rules
        DataElement[] memory extraData = new DataElement[](0); // No extra data

        // Use the FeedFactory to deploy the Feed contract
        vm.startPrank(owner);
        address feedAddress =
            feedFactory.deployFeed(metadataURI, IAccessControl(address(accessControl)), rules, extraData);
        vm.stopPrank();

        // Cast the feedAddress to Feed contract
        feed = Feed(feedAddress);

        // Deploy mock rules
        mockFeedRule = new MockFeedRule();
        mockPostRule = new MockPostRule();

        mockFeedRule2 = new MockFeedRule();
        mockPostRule2 = new MockPostRule();
    }

    // Test adding a feed rule and its enforcement
    function testFeedRuleEnforcement() public {
        vm.startPrank(owner);

        // Configure the mock feed rule to fail
        bytes memory configData = abi.encode(true, true); // shouldRevert = true, shouldReturnFalse = true

        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration({ruleAddress: address(mockFeedRule), configData: configData, isRequired: true});

        // Add the feed rule
        feed.addFeedRules(rules);

        vm.stopPrank();

        // Attempt to create a post; should revert due to the feed rule
        vm.startPrank(user);

        CreatePostParams memory createPostParams = getDefaultCreatePostParams(user);

        vm.expectRevert("Some required rule failed");
        feed.createPost(createPostParams);

        vm.stopPrank();

        // Now update the rule to pass
        vm.startPrank(owner);

        configData = abi.encode(false, false); // shouldRevert = false, shouldReturnFalse = false

        rules[0] = RuleConfiguration({ruleAddress: address(mockFeedRule), configData: configData, isRequired: true});

        feed.updateFeedRules(rules);

        vm.stopPrank();

        // Attempt to create a post again; should succeed
        vm.startPrank(user);

        uint256 postId = feed.createPost(createPostParams);

        vm.stopPrank();

        // Verify that the post was created
        Post memory post = feed.getPost(postId);
        assertEq(post.author, user);
        assertEq(post.contentURI, "ipfs://default-content-uri");
    }

    // Test adding a post rule and its enforcement
    function testPostRuleEnforcement() public {
        vm.startPrank(user);

        // Create a post
        CreatePostParams memory createPostParams = getDefaultCreatePostParams(user);

        uint256 postId = feed.createPost(createPostParams);

        vm.stopPrank();

        // Configure the mock post rule to fail
        bytes memory configData = abi.encode(true, true); // shouldRevert = true, shouldReturnFalse = true

        RuleConfiguration[] memory postRules = new RuleConfiguration[](1);
        postRules[0] = RuleConfiguration({ruleAddress: address(mockPostRule), configData: configData, isRequired: true});

        // Add the post rule
        vm.startPrank(user);

        feed.addPostRules(
            postId,
            postRules,
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0))
        );

        vm.stopPrank();

        // Attempt to create a child post referencing the parent post; should revert
        vm.startPrank(user);

        createPostParams.parentPostId = postId;
        createPostParams.contentURI = "ipfs://child-content-uri";

        vm.expectRevert("Some required rule failed");
        feed.createPost(createPostParams);

        vm.stopPrank();

        // Now update the post rule to pass
        vm.startPrank(user);

        configData = abi.encode(false, false); // shouldRevert = false, shouldReturnFalse = false

        postRules[0] = RuleConfiguration({ruleAddress: address(mockPostRule), configData: configData, isRequired: true});

        feed.updatePostRules(
            postId,
            postRules,
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0))
        );

        vm.stopPrank();

        // Attempt to create the child post again; should succeed
        vm.startPrank(user);

        uint256 childPostId = feed.createPost(createPostParams);

        vm.stopPrank();

        // Verify that the child post was created
        Post memory childPost = feed.getPost(childPostId);
        assertEq(childPost.author, user);
        assertEq(childPost.contentURI, "ipfs://child-content-uri");
    }

    // Test ownership transfer with two-step confirmation
    function testOwnershipTransferWithConfirmation() public {
        // Owner initiates transfer to 'user'
        vm.startPrank(owner);
        accessControl.transferOwnership(user);
        vm.stopPrank();

        // 'user' confirms ownership transfer
        vm.startPrank(user);
        accessControl.confirmOwnershipTransfer();
        vm.stopPrank();

        // Owner confirms ownership transfer
        vm.startPrank(owner);
        accessControl.confirmOwnershipTransfer();
        vm.stopPrank();

        // 'user' should now be able to set metadata URI
        vm.startPrank(user);
        feed.setMetadataURI("New Metadata URI by New Owner");
        vm.stopPrank();

        string memory metadataURI = feed.getMetadataURI();
        assertEq(metadataURI, "New Metadata URI by New Owner");

        // 'owner' should no longer have access
        vm.startPrank(owner);
        vm.expectRevert();
        feed.setMetadataURI("Should Fail");
        vm.stopPrank();
    }

    // Test failure when required rule reverts
    function testRequiredRuleReverts() public {
        vm.startPrank(owner);

        // Configure the mock feed rule to revert
        bytes memory configData = abi.encode(true, false); // shouldRevert = true, shouldReturnFalse = false

        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration({ruleAddress: address(mockFeedRule), configData: configData, isRequired: true});

        // Add the feed rule
        feed.addFeedRules(rules);

        vm.stopPrank();

        // Attempt to create a post; should revert with the rule's revert message
        vm.startPrank(user);

        CreatePostParams memory createPostParams = getDefaultCreatePostParams(user);

        vm.expectRevert("Some required rule failed");
        feed.createPost(createPostParams);

        vm.stopPrank();
    }

    // Test any-of rules
    function testAnyOfRules() public {
        vm.startPrank(owner);

        // Configure two mock feed rules
        bytes memory configDataFailing = abi.encode(false, true); // shouldRevert = false, shouldReturnFalse = true
        bytes memory configDataPassing = abi.encode(false, false); // shouldRevert = false, shouldReturnFalse = false

        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] =
            RuleConfiguration({ruleAddress: address(mockFeedRule), configData: configDataFailing, isRequired: false});
        rules[1] =
            RuleConfiguration({ruleAddress: address(mockFeedRule2), configData: configDataPassing, isRequired: false});

        // Add the any-of feed rules
        feed.addFeedRules(rules);

        vm.stopPrank();

        // Attempt to create a post; should succeed because one of the any-of rules passes
        vm.startPrank(user);

        CreatePostParams memory createPostParams = getDefaultCreatePostParams(user);
        createPostParams.feedRulesData.dataForAnyOfRules[0] = ""; // For failing rule
        createPostParams.feedRulesData.dataForAnyOfRules[1] = ""; // For passing rule

        uint256 postId = feed.createPost(createPostParams);

        vm.stopPrank();

        // Verify that the post was created
        Post memory post = feed.getPost(postId);
        assertEq(post.author, user);
    }

    // Test that all any-of rules failing causes revert
    function testAnyOfRulesAllFailing() public {
        vm.startPrank(owner);

        // Configure two failing any-of feed rules
        bytes memory configDataFailing = abi.encode(false, true); // shouldRevert = false, shouldReturnFalse = true

        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] =
            RuleConfiguration({ruleAddress: address(mockFeedRule), configData: configDataFailing, isRequired: false});
        rules[1] =
            RuleConfiguration({ruleAddress: address(mockFeedRule2), configData: configDataFailing, isRequired: false});

        // Add the any-of feed rules
        feed.addFeedRules(rules);

        vm.stopPrank();

        // Attempt to create a post; should revert because all any-of rules fail
        vm.startPrank(user);

        CreatePostParams memory createPostParams = getDefaultCreatePostParams(user);

        vm.expectRevert("All of the OR rules failed");
        feed.createPost(createPostParams);

        vm.stopPrank();
    }

    // Test creating a repost with rule enforcement
    function testRepostCreationWithRuleEnforcement() public {
        vm.startPrank(user);

        // Create an original post
        CreatePostParams memory createPostParams = getDefaultCreatePostParams(user);

        uint256 originalPostId = feed.createPost(createPostParams);

        vm.stopPrank();

        // Configure the mock post rule to fail on repost
        vm.startPrank(user);

        bytes memory configData = abi.encode(true, true); // shouldRevert = true, shouldReturnFalse = true

        RuleConfiguration[] memory postRules = new RuleConfiguration[](1);
        postRules[0] = RuleConfiguration({ruleAddress: address(mockPostRule), configData: configData, isRequired: true});

        // Add the post rule to the original post
        feed.addPostRules(
            originalPostId,
            postRules,
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0))
        );

        vm.stopPrank();

        // Attempt to create a repost; should revert due to the post rule
        vm.startPrank(otherUser);

        CreateRepostParams memory createRepostParams;
        createRepostParams.author = otherUser;
        createRepostParams.source = otherUser;
        createRepostParams.parentPostId = originalPostId;
        createRepostParams.extraData = new DataElement[](0);
        createRepostParams.parentsPostRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));

        vm.expectRevert("Some required rule failed");
        feed.createRepost(createRepostParams);

        vm.stopPrank();

        // Now update the post rule to pass
        vm.startPrank(user);

        configData = abi.encode(false, false); // shouldRevert = false, shouldReturnFalse = false

        postRules[0] = RuleConfiguration({ruleAddress: address(mockPostRule), configData: configData, isRequired: true});

        feed.updatePostRules(
            originalPostId,
            postRules,
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0))
        );

        vm.stopPrank();

        // Attempt to create the repost again; should succeed
        vm.startPrank(otherUser);

        uint256 repostId = feed.createRepost(createRepostParams);

        vm.stopPrank();

        // Verify that the repost was created
        Post memory repost = feed.getPost(repostId);
        assertEq(repost.author, otherUser);
        assertEq(repost.isRepost, true);
        assertEq(repost.parentPostId, originalPostId);
    }

    // Test editing a post with rule enforcement
    function testEditPostWithRuleEnforcement() public {
        vm.startPrank(user);

        // Create a post
        CreatePostParams memory createPostParams = getDefaultCreatePostParams(user);

        uint256 postId = feed.createPost(createPostParams);

        vm.stopPrank();

        // Configure the mock feed rule to fail on edit
        vm.startPrank(owner);

        bytes memory configData = abi.encode(true, true); // shouldRevert = true, shouldReturnFalse = true

        RuleConfiguration[] memory feedRules = new RuleConfiguration[](1);
        feedRules[0] = RuleConfiguration({ruleAddress: address(mockFeedRule), configData: configData, isRequired: true});

        // Add the feed rule
        feed.addFeedRules(feedRules);

        vm.stopPrank();

        // Attempt to edit the post; should revert due to the feed rule
        vm.startPrank(user);

        EditPostParams memory editPostParams;
        editPostParams.contentURI = "ipfs://edited-content-uri";
        editPostParams.extraData = new DataElement[](0);

        RuleExecutionData memory feedRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        feedRulesData.dataForRequiredRules[0] = ""; // No additional data

        vm.expectRevert("Some required rule failed");
        feed.editPost(postId, editPostParams, feedRulesData);

        vm.stopPrank();

        // Now update the feed rule to pass
        vm.startPrank(owner);

        configData = abi.encode(false, false); // shouldRevert = false, shouldReturnFalse = false

        feedRules[0] = RuleConfiguration({ruleAddress: address(mockFeedRule), configData: configData, isRequired: true});

        feed.updateFeedRules(feedRules);

        vm.stopPrank();

        // Attempt to edit the post again; should succeed
        vm.startPrank(user);

        feed.editPost(postId, editPostParams, feedRulesData);

        vm.stopPrank();

        // Verify that the post was edited
        Post memory post = feed.getPost(postId);
        assertEq(post.contentURI, "ipfs://edited-content-uri");
    }

    // Test deleting a post with rule enforcement
    function testDeletePostWithRuleEnforcement() public {
        vm.startPrank(user);

        // Create a post
        CreatePostParams memory createPostParams = getDefaultCreatePostParams(user);

        uint256 postId = feed.createPost(createPostParams);

        vm.stopPrank();

        // Configure the mock feed rule to fail on delete
        vm.startPrank(owner);

        bytes memory configData = abi.encode(true, true); // shouldRevert = true, shouldReturnFalse = true

        RuleConfiguration[] memory feedRules = new RuleConfiguration[](1);
        feedRules[0] = RuleConfiguration({ruleAddress: address(mockFeedRule), configData: configData, isRequired: true});

        // Add the feed rule
        feed.addFeedRules(feedRules);

        vm.stopPrank();

        // Attempt to delete the post; should revert due to the feed rule
        vm.startPrank(user);

        RuleExecutionData memory feedRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        feedRulesData.dataForRequiredRules[0] = ""; // No additional data

        vm.expectRevert("Some required rule failed");
        feed.deletePost(postId, new bytes32[](0), feedRulesData);

        vm.stopPrank();

        // Now update the feed rule to pass
        vm.startPrank(owner);

        configData = abi.encode(false, false); // shouldRevert = false, shouldReturnFalse = false

        feedRules[0] = RuleConfiguration({ruleAddress: address(mockFeedRule), configData: configData, isRequired: true});

        feed.updateFeedRules(feedRules);

        vm.stopPrank();

        // Attempt to delete the post again; should succeed
        vm.startPrank(user);

        feed.deletePost(postId, new bytes32[](0), feedRulesData);

        vm.stopPrank();

        // Verify that the post was deleted
        Post memory post = feed.getPost(postId);
        assertEq(post.author, address(0), "Post author should be address(0) after deletion");
        assertEq(post.contentURI, "", "Post contentURI should be empty after deletion");
    }

    function testCreatePostWithDifferentAuthorShouldFail() public {
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(otherUser); // Different author
        vm.expectRevert("MSG_SENDER_NOT_AUTHOR");
        feed.createPost(params);
        vm.stopPrank();
    }

    function testCreatePostWithMultipleAuthorsInExtraData() public {
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.extraData = new DataElement[](1);
        params.extraData[0] = DataElement({key: keccak256("additional_authors"), value: abi.encode([user, otherUser])});
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        // Retrieve and verify the extra data
        DataElementValue memory extraData = feed.getPostExtraData(postId, keccak256("additional_authors"));
        address[2] memory authors = abi.decode(extraData.value, (address[2]));
        assertEq(authors.length, 2);
        assertEq(authors[0], user);
        assertEq(authors[1], otherUser);
    }

    function testCreatePostWithSpecificSource() public {
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.source = otherUser;
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        Post memory post = feed.getPost(postId);
        assertEq(post.source, otherUser);
    }

    function testCreatePostWithZeroAddressSource() public {
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.source = address(0);
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        Post memory post = feed.getPost(postId);
        assertEq(post.source, address(0));
    }

    function testCreatePostWithContentURI() public {
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.contentURI = "ipfs://custom-content-uri";
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        Post memory post = feed.getPost(postId);
        assertEq(post.contentURI, "ipfs://custom-content-uri");
    }

    function testCreatePostWithEmptyContentURI() public {
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.contentURI = "";
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        Post memory post = feed.getPost(postId);
        assertEq(post.contentURI, "");
    }

    function testCreatePostWithValidQuotedPost() public {
        // Create a post to quote
        vm.startPrank(otherUser);
        uint256 quotedPostId = feed.createPost(getDefaultCreatePostParams(otherUser));
        vm.stopPrank();

        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.quotedPostId = quotedPostId;
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        Post memory post = feed.getPost(postId);
        assertEq(post.quotedPostId, quotedPostId);
    }

    function testCreatePostWithNonExistentQuotedPostShouldFail() public {
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.quotedPostId = 9999; // Non-existent
        vm.expectRevert("POST_DOES_NOT_EXIST");
        feed.createPost(params);
        vm.stopPrank();
    }

    function testCreatePostQuotingRepostShouldFail() public {
        // Create a repost
        vm.startPrank(otherUser);
        uint256 originalPostId = feed.createPost(getDefaultCreatePostParams(otherUser));
        CreateRepostParams memory repostParams = CreateRepostParams({
            author: otherUser,
            source: otherUser,
            parentPostId: originalPostId,
            extraData: new DataElement[](0),
            feedRulesData: RuleExecutionData(new bytes[](0), new bytes[](0)),
            parentsPostRulesData: RuleExecutionData(new bytes[](0), new bytes[](0))
        });
        uint256 repostId = feed.createRepost(repostParams);
        vm.stopPrank();

        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.quotedPostId = repostId;
        vm.expectRevert("REPOST_CANNOT_BE_QUOTED");
        feed.createPost(params);
        vm.stopPrank();
    }

    function testCreatePostWithValidParentPost() public {
        // Create a parent post
        vm.startPrank(otherUser);
        uint256 parentPostId = feed.createPost(getDefaultCreatePostParams(otherUser));
        vm.stopPrank();

        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.parentPostId = parentPostId;
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        Post memory post = feed.getPost(postId);
        assertEq(post.parentPostId, parentPostId);
    }

    function testCreatePostWithNonExistentParentPostShouldFail() public {
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.parentPostId = 9999; // Non-existent
        vm.expectRevert();
        feed.createPost(params);
        vm.stopPrank();
    }

    function testCreatePostReplyingToRepostShouldFail() public {
        // Create a repost
        vm.startPrank(otherUser);
        uint256 originalPostId = feed.createPost(getDefaultCreatePostParams(otherUser));
        CreateRepostParams memory repostParams = CreateRepostParams({
            author: otherUser,
            source: otherUser,
            parentPostId: originalPostId,
            extraData: new DataElement[](0),
            feedRulesData: RuleExecutionData(new bytes[](0), new bytes[](0)),
            parentsPostRulesData: RuleExecutionData(new bytes[](0), new bytes[](0))
        });
        uint256 repostId = feed.createRepost(repostParams);
        vm.stopPrank();

        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.parentPostId = repostId;
        vm.expectRevert("REPOST_CANNOT_BE_PARENT");
        feed.createPost(params);
        vm.stopPrank();
    }

    function testCreatePostWithRules() public {
        // Configure a mock post rule that will fail
        bytes memory configData = abi.encode(true, true); // shouldReturnFalse = true

        RuleConfiguration[] memory postRules = new RuleConfiguration[](1);
        postRules[0] = RuleConfiguration({ruleAddress: address(mockPostRule), configData: configData, isRequired: true});

        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.rules = postRules;

        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        address[] memory rules = feed.getPostRules(postId, true);
        assertEq(rules[0], address(mockPostRule));
    }

    function testCreatePostWithFeedRulesData() public {
        // Assume mockFeedRule can validate data
        vm.startPrank(owner);
        bytes memory configData = abi.encode(false, false);
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration({ruleAddress: address(mockFeedRule), configData: configData, isRequired: true});
        feed.addFeedRules(rules);
        vm.stopPrank();

        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.feedRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        params.feedRulesData.dataForRequiredRules[0] = abi.encode("test data");
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        // Verify post creation succeeded
        Post memory post = feed.getPost(postId);
        assertEq(post.author, user);
    }

    function testCreatePostWithChangeRulesData() public {
        // Create a parent post with a rule
        vm.startPrank(otherUser);
        uint256 parentPostId = feed.createPost(getDefaultCreatePostParams(otherUser));
        bytes memory configData = abi.encode(false, false);
        RuleConfiguration[] memory parentRules = new RuleConfiguration[](1);
        parentRules[0] =
            RuleConfiguration({ruleAddress: address(mockPostRule), configData: configData, isRequired: true});
        feed.addPostRules(
            parentPostId,
            parentRules,
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0))
        );
        vm.stopPrank();

        // Create a post with changeRulesParentPostRulesData
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.parentPostId = parentPostId;
        params.parentsPostRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        params.changeRulesParentPostRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        params.changeRulesParentPostRulesData.dataForRequiredRules[0] = abi.encode("test data");
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        // Verify post creation succeeded
        Post memory post = feed.getPost(postId);
        assertEq(post.parentPostId, parentPostId);
    }

    function testCreatePostWithParentsPostRulesData() public {
        // Create a parent post with a rule that requires specific data
        vm.startPrank(otherUser);
        uint256 parentPostId = feed.createPost(getDefaultCreatePostParams(otherUser));
        bytes memory configData = abi.encode(false, false);
        RuleConfiguration[] memory parentRules = new RuleConfiguration[](1);
        parentRules[0] =
            RuleConfiguration({ruleAddress: address(mockPostRule), configData: configData, isRequired: true});
        feed.addPostRules(
            parentPostId,
            parentRules,
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0)),
            RuleExecutionData(new bytes[](0), new bytes[](0))
        );
        vm.stopPrank();

        // Create a post replying to parent, providing required data
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.changeRulesParentPostRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        params.parentPostId = parentPostId;
        params.parentsPostRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        params.parentsPostRulesData.dataForRequiredRules[0] = abi.encode("required data");
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        // Verify post creation succeeded
        Post memory post = feed.getPost(postId);
        assertEq(post.parentPostId, parentPostId);
    }

    function testCreatePostWithExtraData() public {
        vm.startPrank(user);
        CreatePostParams memory params = getDefaultCreatePostParams(user);
        params.extraData = new DataElement[](2);
        params.extraData[0] = DataElement({key: keccak256("category"), value: abi.encode("news")});
        params.extraData[1] = DataElement({key: keccak256("language"), value: abi.encode("en")});
        uint256 postId = feed.createPost(params);
        vm.stopPrank();

        // Verify extra data
        DataElementValue memory categoryData = feed.getPostExtraData(postId, keccak256("category"));
        string memory category = abi.decode(categoryData.value, (string));
        assertEq(category, "news");

        DataElementValue memory languageData = feed.getPostExtraData(postId, keccak256("language"));
        string memory language = abi.decode(languageData.value, (string));
        assertEq(language, "en");
    }

    // --------- Helpers ------------------------

    function getDefaultCreatePostParams(address _author) internal pure returns (CreatePostParams memory) {
        CreatePostParams memory params;
        params.author = _author;
        params.source = _author;
        params.contentURI = "ipfs://default-content-uri";
        params.quotedPostId = 0;
        params.parentPostId = 0;
        params.rules = new RuleConfiguration[](0);
        params.extraData = new DataElement[](0);
        params.feedRulesData = RuleExecutionData(new bytes[](1), new bytes[](2));
        params.changeRulesQuotePostRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        params.changeRulesParentPostRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        params.quotesPostRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        params.parentsPostRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        return params;
    }
}
