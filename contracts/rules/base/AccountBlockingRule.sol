// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";
import {IGraphRule} from "contracts/core/interfaces/IGraphRule.sol";
import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";
import {KeyValue, RuleChange} from "contracts/core/types/Types.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract AccountBlockingRule is IFeedRule, IGraphRule, MetadataBased {
    event Lens_AccountBlocking_AccountBlocked(address indexed source, address indexed target, uint256 timestamp);
    event Lens_AccountBlocking_UserUnblocked(address indexed source, address indexed target);

    event Lens_Rule_MetadataURISet(string metadataURI);

    mapping(address => mapping(address => uint256)) public accountBlocks;

    constructor(string memory metadataURI) {
        _setMetadataURI(metadataURI);
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Rule_MetadataURISet(metadataURI);
    }

    function configure(bytes32, /* salt */ KeyValue[] calldata /* ruleConfigurationParams */ )
        external
        pure
        override(IFeedRule, IGraphRule)
    {}

    function blockUser(address source, address target) external {
        require(msg.sender == source, Errors.InvalidMsgSender());
        require(source != target, Errors.ActionOnSelf());
        accountBlocks[source][target] = block.timestamp;
    }

    function unblockUser(address source, address target) external {
        require(msg.sender == source, Errors.InvalidMsgSender());
        accountBlocks[msg.sender][target] = 0;
    }

    function processCreatePost(
        bytes32, /* configSalt */
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external view {
        if (postParams.repliedPostId != 0) {
            address author = postParams.author;
            address repliedToAuthor = IFeed(msg.sender).getPostAuthor(postParams.repliedPostId);
            uint256 rootPostId = IFeed(msg.sender).getPost(postId).rootPostId;
            address rootAuthor = IFeed(msg.sender).getPostAuthor(rootPostId);
            if (_isBlocked({source: repliedToAuthor, blockTarget: author})) {
                revert Errors.Blocked();
            }
            if (_isBlocked({source: rootAuthor, blockTarget: author})) {
                revert Errors.Blocked();
            }
        }
    }

    function processFollow(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external view {
        if (_isBlocked({source: accountToFollow, blockTarget: followerAccount})) {
            revert Errors.Blocked();
        }
    }

    function isBlocked(address source, address blockTarget) external view returns (bool) {
        return _isBlocked(source, blockTarget);
    }

    function _isBlocked(address source, address blockTarget) internal view returns (bool) {
        return accountBlocks[source][blockTarget] > 0;
    }

    // Unimplemented functions

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure {
        revert Errors.NotImplemented();
    }

    function processDeletePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure {
        revert Errors.NotImplemented();
    }

    function processPostRuleChanges(
        bytes32, /* configSalt */
        uint256, /* postId */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure {
        revert Errors.NotImplemented();
    }

    function processUnfollow(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* followerAccount */
        address, /* accountToUnfollow */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure {
        revert Errors.NotImplemented();
    }

    function processFollowRuleChanges(
        bytes32, /* configSalt */
        address, /* account */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure {
        revert Errors.NotImplemented();
    }
}
