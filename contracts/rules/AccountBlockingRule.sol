// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";
import {IGraphRule} from "contracts/core/interfaces/IGraphRule.sol";
import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";
import {KeyValue, RuleChange} from "contracts/core/types/Types.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract AccountBlockingRule is OwnableMetadataBasedRule, Initializable, IFeedRule, IGraphRule {
    event Lens_AccountBlocking_AccountBlocked(address indexed source, address indexed target);
    event Lens_AccountBlocking_AccountUnblocked(address indexed source, address indexed target);

    struct Storage {
        mapping(address source => mapping(address target => bool isBlocked)) isBlocked;
    }

    /// @custom:keccak lens.storage.AccountBlockingRule
    bytes32 constant STORAGE__ACCOUNT_BLOCKING_RULE = 0xe12472e4fa1ab16991a1a948dff8ec39ff46bdd19194555f802f78a18b5506a0;

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__ACCOUNT_BLOCKING_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32, /* salt */ KeyValue[] calldata /* ruleConfigurationParams */ )
        external
        pure
        override(IFeedRule, IGraphRule)
    {}

    function blockUser(address source, address target) external {
        require(msg.sender == source, Errors.InvalidMsgSender());
        require(source != target, Errors.ActionOnSelf());
        require(!$storage().isBlocked[source][target], Errors.RedundantStateChange());
        $storage().isBlocked[source][target] = true;
        emit Lens_AccountBlocking_AccountBlocked(source, target);
    }

    function unblockUser(address source, address target) external {
        require(msg.sender == source, Errors.InvalidMsgSender());
        require($storage().isBlocked[source][target], Errors.RedundantStateChange());
        $storage().isBlocked[source][target] = false;
        emit Lens_AccountBlocking_AccountUnblocked(source, target);
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
            if ($storage().isBlocked[repliedToAuthor][author]) {
                revert Errors.Blocked();
            }
            if ($storage().isBlocked[rootAuthor][author]) {
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
        if ($storage().isBlocked[accountToFollow][followerAccount]) {
            revert Errors.Blocked();
        }
    }

    function isBlocked(address source, address blockTarget) external view returns (bool) {
        return $storage().isBlocked[source][blockTarget];
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
