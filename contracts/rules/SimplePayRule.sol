// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IGraphRule} from "./../primitives/graph/IGraphRule.sol";
import {IFollowRule} from "./../primitives/graph/IFollowRule.sol";
import {IFeedRule} from "./../primitives/feed/IFeedRule.sol";
import {IPostRule} from "./../primitives/feed/IPostRule.sol";
import {IGroupRule} from "./../primitives/group/IGroupRule.sol";
import {IUsernameRule} from "./../primitives/username/IUsernameRule.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CreatePostParams, EditPostParams, Post, IFeed} from "./../primitives/feed/IFeed.sol";
import {RuleConfiguration} from "./../types/Types.sol";

struct SimplePayConfiguration {
    uint256 amount;
    address token;
    address recipient;
}

// This is a Simple PayToDoSomething rule that requires payments for actions on a primitive or primitive's entities.
// It doesn't have any specific configuration of which actions to bill for, it just bills equally for all actions.
// Other rules can be more specific and differentiate between actions to bill for (pay to quote, per username char etc).
contract SimplePayRule is IFeedRule, IPostRule, IGraphRule, IFollowRule, IGroupRule, IUsernameRule {
    using SafeERC20 for IERC20;

    mapping(address primitive => SimplePayConfiguration) internal _primitiveConfigurations;
    mapping(address primitive => mapping(uint256 postId => SimplePayConfiguration)) internal _feedPostConfigurations;
    mapping(address primitive => mapping(address account => SimplePayConfiguration)) internal
        _graphAccountConfigurations;

    // Rules configure() functions are called by the primitive (as msg.sender)

    // IFeedRule, IGraphRule, IGroupRule, IUsernameRule (configuration per primitive)
    function configure(bytes calldata data) external override(IFeedRule, IGraphRule, IGroupRule, IUsernameRule) {
        _primitiveConfigurations[msg.sender] = abi.decode(data, (SimplePayConfiguration));
    }

    // IPostRule (configuration per postId)
    function configure(uint256 postId, bytes calldata data) external {
        _feedPostConfigurations[msg.sender][postId] = abi.decode(data, (SimplePayConfiguration));
    }

    // IFollowRule (configuration per account)
    function configure(address account, bytes calldata data) external {
        _graphAccountConfigurations[msg.sender][account] = abi.decode(data, (SimplePayConfiguration));
    }

    // We transfer money from the primitive, because we cannot trust primitives to pass a correct account to the rule.
    // Rules process() functions are called from the primitive (as msg.sender)

    // PRIMITIVE BASED PROCESSING:

    // IFeedRule processing

    function processCreatePost(
        uint256 postId,
        uint256, /* localSequentialId */
        CreatePostParams calldata, /* postParams */
        bytes calldata /* data */
    ) external returns (bool) {
        _complexPostTypeProcessingLogic(postId);
        return true;
    }

    function processEditPost(
        uint256 postId,
        uint256, /* localSequentialId */
        EditPostParams calldata, /* editPostParams */
        bytes calldata /* data */
    ) external returns (bool) {
        _complexPostTypeProcessingLogic(postId);
        return true;
    }

    function processDeletePost(uint256 postId, uint256, /* localSequentialId */ bytes calldata /* data */ )
        external
        returns (bool)
    {
        _complexPostTypeProcessingLogic(postId);
        return true;
    }

    function processPostRulesChanged(
        uint256 postId,
        uint256, /* localSequentialId */
        RuleConfiguration[] calldata, /* newPostRules */
        bytes calldata /* data */
    ) external returns (bool) {
        _complexPostTypeProcessingLogic(postId);
        return true;
    }

    // IGraphRule processing

    function processFollow(
        address, /* followerAcount */
        address, /* accountToFollow */
        uint256, /* followId */
        bytes calldata /* data */
    ) external returns (bool) {
        _processPayment(_primitiveConfigurations[msg.sender]);
        return true;
    }

    function processUnfollow(
        address, /* unfollowerAccount */
        address, /* accountToUnfollow */
        uint256, /* followId */
        bytes calldata /* data */
    ) external returns (bool) {
        _processPayment(_primitiveConfigurations[msg.sender]);
        return true;
    }

    function processFollowRulesChange(
        address, /* account */
        RuleConfiguration[] calldata, /* followRules */
        bytes calldata /* data */
    ) external returns (bool) {
        _processPayment(_primitiveConfigurations[msg.sender]);
        return true;
    }

    // IGroupRule processing

    function processJoining(address, /* account */ uint256, /* membershipId */ bytes calldata /* data */ )
        external
        returns (bool)
    {
        _processPayment(_primitiveConfigurations[msg.sender]);
        return true;
    }

    function processRemoval(address, /* account */ uint256, /* membershipId */ bytes calldata /* data */ )
        external
        returns (bool)
    {
        _processPayment(_primitiveConfigurations[msg.sender]);
        return true;
    }

    function processLeaving(address, /* account */ uint256, /* membershipId */ bytes calldata /* data */ )
        external
        returns (bool)
    {
        _processPayment(_primitiveConfigurations[msg.sender]);
        return true;
    }

    // IUsernameRule processing

    function processCreation(address, /* account */ string calldata, /* username */ bytes calldata /* data */ )
        external
        returns (bool)
    {
        _processPayment(_primitiveConfigurations[msg.sender]);
        return true;
    }

    function processRemoval(address, /* account */ string calldata, /* username */ bytes calldata /* data */ )
        external
        returns (bool)
    {
        _processPayment(_primitiveConfigurations[msg.sender]);
        return true;
    }

    function processAssigning(address, /* account */ string calldata, /* username */ bytes calldata /* data */ )
        external
        returns (bool)
    {
        _processPayment(_primitiveConfigurations[msg.sender]);
        return true;
    }

    function processUnassigning(address, /* account */ string calldata, /* username */ bytes calldata /* data */ )
        external
        returns (bool)
    {
        _processPayment(_primitiveConfigurations[msg.sender]);
        return true;
    }

    // ENTITY BASED PROCESSING:

    // IPostRule processing

    function processQuote(
        uint256, /* rootPostId */
        uint256, /* quotedPostId */
        uint256 postId,
        bytes calldata /* data */
    ) external returns (bool) {
        _processPayment(_feedPostConfigurations[msg.sender][postId]);
        return true;
    }

    function processReply(
        uint256, /* rootPostId */
        uint256, /* repliedPostId */
        uint256 postId,
        bytes calldata /* data */
    ) external returns (bool) {
        _processPayment(_feedPostConfigurations[msg.sender][postId]);
        return true;
    }

    function processRepost(
        uint256, /* rootPostId */
        uint256, /* repostedPostId */
        uint256 postId,
        bytes calldata /* data */
    ) external returns (bool) {
        _processPayment(_feedPostConfigurations[msg.sender][postId]);
        return true;
    }

    // IFollowRule processing

    function processFollowLocal(
        address, /* followerAccount */
        address accountToFollow,
        uint256, /* followId */
        bytes calldata /* data */
    ) external returns (bool) {
        _processPayment(_graphAccountConfigurations[msg.sender][accountToFollow]);
        return true;
    }

    // Internal functions

    function _processPayment(SimplePayConfiguration memory configuration) internal {
        if (configuration.amount > 0) {
            IERC20(configuration.token).safeTransferFrom(msg.sender, configuration.recipient, configuration.amount);
        }
    }

    function _complexPostTypeProcessingLogic(uint256 postId) internal {
        // TODO: Think if we can optimize this not fetching everything from storage
        Post memory postParams = IFeed(msg.sender).getPost(postId);
        uint256 rootPostId = postParams.rootPostId;

        if (rootPostId == postId) {
            if (postParams.quotedPostId == 0) {
                // Post is a simple root post (not a quote, reply or repost)
                _processPayment(_primitiveConfigurations[msg.sender]);
            } else {
                // Post is a quote
                _processPayment(_feedPostConfigurations[msg.sender][postParams.quotedPostId]);
            }
        } else {
            // Post is either a repost or a reply
            if (postParams.repostedPostId > 0) {
                // Post is a repost
                _processPayment(_feedPostConfigurations[msg.sender][postParams.repostedPostId]);
            } else {
                // Post is a reply (with or without a quote)
                if (postParams.quotedPostId > 0) {
                    // Post is a reply with a quote
                    _processPayment(_feedPostConfigurations[msg.sender][postParams.quotedPostId]);
                } else {
                    // Post is a simple reply
                    _processPayment(_feedPostConfigurations[msg.sender][postParams.repliedPostId]);
                }
            }
        }
    }
}
