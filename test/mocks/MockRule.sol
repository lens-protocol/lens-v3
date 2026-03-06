// SPDX-License-Identifier: GPL-3.0-only
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
import {LensRulePaymentHandler} from "@extensions/fees/LensRulePaymentHandler.sol";
import {NATIVE_TOKEN} from "@core/types/Constants.sol";

interface IPrimitiveRule {
    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external;
}

contract MockRule is
    LensRulePaymentHandler,
    INamespaceRule,
    IGraphRule,
    IFeedRule,
    IGroupRule,
    IFollowRule,
    IPostRule
{
    mapping(bytes4 => bool) internal _shouldSelectorRevert;
    mapping(bytes4 => uint256) internal _nativeAmountToPullBySelector;
    mapping(bytes4 => address) internal _nativeRecipientBySelector;

    function mockToRevertOn(bytes4 selector) external {
        _shouldSelectorRevert[selector] = true;
    }

    function mockToSucceedOn(bytes4 selector) external {
        _shouldSelectorRevert[selector] = false;
    }

    function mockToPullNativeOn(bytes4 selector, uint256 amount) external {
        _nativeAmountToPullBySelector[selector] = amount;
        _nativeRecipientBySelector[selector] = address(this);
    }

    function mockToTransferNativeOn(bytes4 selector, address to, uint256 amount) external {
        _nativeAmountToPullBySelector[selector] = amount;
        _nativeRecipientBySelector[selector] = to;
    }

    fallback() external payable {
        require(!_shouldSelectorRevert[msg.sig]);
    }

    receive() external payable {}

    function _transferNativeIfNeeded(bytes4 selector) internal {
        uint256 amount = _nativeAmountToPullBySelector[selector];
        if (amount > 0) {
            _sendToken(NATIVE_TOKEN, address(0), _nativeRecipientBySelector[selector], amount);
        }
    }

    function configure(bytes32, /* configSalt */ KeyValue[] calldata /* ruleParams */ )
        external
        override(IFeedRule, IGraphRule, IGroupRule, INamespaceRule)
    {
        require(!_shouldSelectorRevert[IPrimitiveRule.configure.selector]);
        _transferNativeIfNeeded(IPrimitiveRule.configure.selector);
    }

    function configure(bytes32, /* configSalt */ uint256, /* postId */ KeyValue[] calldata /* ruleParams */ )
        external
        override
    {
        require(!_shouldSelectorRevert[IPostRule.configure.selector]);
        _transferNativeIfNeeded(IPostRule.configure.selector);
    }

    function configure(bytes32, /* configSalt */ address, /* account */ KeyValue[] calldata /* ruleParams */ )
        external
        override
    {
        require(!_shouldSelectorRevert[IFollowRule.configure.selector]);
        _transferNativeIfNeeded(IFollowRule.configure.selector);
    }

    function processCreation(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[INamespaceRule.processCreation.selector]);
        _transferNativeIfNeeded(INamespaceRule.processCreation.selector);
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[INamespaceRule.processRemoval.selector]);
        _transferNativeIfNeeded(INamespaceRule.processRemoval.selector);
    }

    function processAssigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[INamespaceRule.processAssigning.selector]);
        _transferNativeIfNeeded(INamespaceRule.processAssigning.selector);
    }

    function processUnassigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[INamespaceRule.processUnassigning.selector]);
        _transferNativeIfNeeded(INamespaceRule.processUnassigning.selector);
    }

    function processFollow(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* followerAccount */
        address, /* accountToFollow */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override(IFollowRule, IGraphRule) {
        require(!_shouldSelectorRevert[IGraphRule.processFollow.selector]);
        _transferNativeIfNeeded(IGraphRule.processFollow.selector);
    }

    function processUnfollow(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* followerAccount */
        address, /* accountToUnfollow */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IGraphRule.processUnfollow.selector]);
        _transferNativeIfNeeded(IGraphRule.processUnfollow.selector);
    }

    function processFollowRuleChanges(
        bytes32, /* configSalt */
        address, /* account */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IGraphRule.processFollowRuleChanges.selector]);
        _transferNativeIfNeeded(IGraphRule.processFollowRuleChanges.selector);
    }

    function processCreatePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        CreatePostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IFeedRule.processCreatePost.selector]);
        _transferNativeIfNeeded(IFeedRule.processCreatePost.selector);
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IFeedRule.processEditPost.selector]);
        _transferNativeIfNeeded(IFeedRule.processEditPost.selector);
    }

    function processDeletePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IFeedRule.processDeletePost.selector]);
        _transferNativeIfNeeded(IFeedRule.processDeletePost.selector);
    }

    function processPostRuleChanges(
        bytes32, /* configSalt */
        uint256, /* postId */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IFeedRule.processPostRuleChanges.selector]);
        _transferNativeIfNeeded(IFeedRule.processPostRuleChanges.selector);
    }

    function processAddition(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IGroupRule.processAddition.selector]);
        _transferNativeIfNeeded(IGroupRule.processAddition.selector);
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IGroupRule.processRemoval.selector]);
        _transferNativeIfNeeded(IGroupRule.processRemoval.selector);
    }

    function processJoining(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IGroupRule.processJoining.selector]);
        _transferNativeIfNeeded(IGroupRule.processJoining.selector);
    }

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IGroupRule.processLeaving.selector]);
        _transferNativeIfNeeded(IGroupRule.processLeaving.selector);
    }

    function processCreatePost(
        bytes32, /* configSalt */
        uint256, /* rootPostId */
        uint256, /* postId */
        CreatePostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IPostRule.processCreatePost.selector]);
        _transferNativeIfNeeded(IPostRule.processCreatePost.selector);
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* rootPostId */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(!_shouldSelectorRevert[IPostRule.processEditPost.selector]);
        _transferNativeIfNeeded(IPostRule.processEditPost.selector);
    }
}
