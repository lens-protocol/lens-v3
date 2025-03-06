// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {INamespaceRule} from "@core/interfaces/INamespaceRule.sol";
import {IGraphRule} from "@core/interfaces/IGraphRule.sol";
import {IFeedRule} from "@core/interfaces/IFeedRule.sol";
import {IGroupRule} from "@core/interfaces/IGroupRule.sol";
import {IFollowRule} from "@core/interfaces/IFollowRule.sol";
import {IPostRule} from "@core/interfaces/IPostRule.sol";
import {KeyValue} from "@core/types/Types.sol";
import {RuleChange} from "@core/types/Types.sol";
import {CreatePostParams, EditPostParams} from "@core/interfaces/IFeed.sol";

interface IPrimitiveRule {
    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external;
}

contract MockRule is INamespaceRule, IGraphRule, IFeedRule, IGroupRule, IFollowRule, IPostRule {
    function testMockRule() public {
        // Prevents being included in the foundry coverage report
    }

    mapping(bytes4 => bool) internal _shouldSelectorRevert;

    function mockToRevertOn(bytes4 selector) external {
        _shouldSelectorRevert[selector] = true;
    }

    function mockToSucceedOn(bytes4 selector) external {
        _shouldSelectorRevert[selector] = false;
    }

    fallback() external {
        require(!_shouldSelectorRevert[msg.sig]);
    }

    function configure(bytes32, /* configSalt */ KeyValue[] calldata /* ruleParams */ )
        external
        view
        override(IFeedRule, IGraphRule, IGroupRule, INamespaceRule)
    {
        require(!_shouldSelectorRevert[IPrimitiveRule.configure.selector]);
    }

    function configure(bytes32, /* configSalt */ uint256, /* postId */ KeyValue[] calldata /* ruleParams */ )
        external
        view
        override
    {
        require(!_shouldSelectorRevert[IPostRule.configure.selector]);
    }

    function configure(bytes32, /* configSalt */ address, /* account */ KeyValue[] calldata /* ruleParams */ )
        external
        view
        override
    {
        require(!_shouldSelectorRevert[IFollowRule.configure.selector]);
    }

    function processCreation(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[INamespaceRule.processCreation.selector]);
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[INamespaceRule.processRemoval.selector]);
    }

    function processAssigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[INamespaceRule.processAssigning.selector]);
    }

    function processUnassigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[INamespaceRule.processUnassigning.selector]);
    }

    function processFollow(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* followerAccount */
        address, /* accountToFollow */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override(IFollowRule, IGraphRule) {
        require(!_shouldSelectorRevert[IGraphRule.processFollow.selector]);
    }

    function processUnfollow(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* followerAccount */
        address, /* accountToUnfollow */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IGraphRule.processUnfollow.selector]);
    }

    function processFollowRuleChanges(
        bytes32, /* configSalt */
        address, /* account */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IGraphRule.processFollowRuleChanges.selector]);
    }

    function processCreatePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        CreatePostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IFeedRule.processCreatePost.selector]);
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IFeedRule.processEditPost.selector]);
    }

    function processDeletePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IFeedRule.processDeletePost.selector]);
    }

    function processPostRuleChanges(
        bytes32, /* configSalt */
        uint256, /* postId */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IFeedRule.processPostRuleChanges.selector]);
    }

    function processAddition(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IGroupRule.processAddition.selector]);
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IGroupRule.processRemoval.selector]);
    }

    function processJoining(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IGroupRule.processJoining.selector]);
    }

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IGroupRule.processLeaving.selector]);
    }

    function processCreatePost(
        bytes32, /* configSalt */
        uint256, /* rootPostId */
        uint256, /* postId */
        CreatePostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IPostRule.processCreatePost.selector]);
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* rootPostId */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_shouldSelectorRevert[IPostRule.processEditPost.selector]);
    }
}
