// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {FeedRuleBase} from "./FeedRuleBase.sol";
import {CreatePostParams, EditPostParams} from "./../IFeed.sol";
import {RuleConfiguration} from "./../../../types/Types.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct PaidRuleConfig {
    address token;
    uint256 amount;
    address recipient;
}

contract SimplePaidFeed is FeedRuleBase {
    using SafeERC20 for IERC20;

    function _processCreatePost(
        bytes memory config,
        uint256, /* postId */
        uint256, /* localSequentialId */
        CreatePostParams calldata, /* postParams */
        bytes calldata /* data */
    ) internal override returns (bool) {
        PaidRuleConfig memory paidRuleConfig = abi.decode(config, (PaidRuleConfig));
        _processPayment(paidRuleConfig);
        return true;
    }

    function _processEditPost(
        bytes memory config,
        uint256, /* postId */
        uint256, /* localSequentialId */
        EditPostParams calldata, /* editPostParams */
        bytes calldata /* data */
    ) internal override returns (bool) {
        PaidRuleConfig memory paidRuleConfig = abi.decode(config, (PaidRuleConfig));
        _processPayment(paidRuleConfig);
        return true;
    }

    function _processDeletePost(
        bytes memory config,
        uint256, /* postId */
        uint256, /* localSequentialId */
        bytes calldata /* data */
    ) internal override returns (bool) {
        PaidRuleConfig memory paidRuleConfig = abi.decode(config, (PaidRuleConfig));
        _processPayment(paidRuleConfig);
        return true;
    }

    function _processPostRulesChanged(
        bytes memory config,
        uint256, /* postId */
        uint256, /* localSequentialId */
        RuleConfiguration[] calldata, /* newPostRules */
        bytes calldata /* data */
    ) internal override returns (bool) {
        PaidRuleConfig memory paidRuleConfig = abi.decode(config, (PaidRuleConfig));
        _processPayment(paidRuleConfig);
        return true;
    }

    // We transfer money from the primitive, because we cannot trust primitives to pass a correct account to the rule.
    // Rules process() functions are called from the primitive (as msg.sender)
    function _processPayment(PaidRuleConfig memory config) internal {
        if (config.amount > 0) {
            IERC20(config.token).safeTransferFrom(msg.sender, config.recipient, config.amount);
        }
    }
}
