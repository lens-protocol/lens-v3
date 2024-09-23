// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRule} from "./../rules/IRule.sol";

interface IGraphRule is IRule {
    bytes4 constant FOLLOW_SELECTOR = bytes4(keccak256("processFollow(address,address,address,uint256,bytes)"));
    bytes4 constant UNFOLLOW_SELECTOR = bytes4(keccak256("processUnfollow(address,address,address,uint256,bytes)"));
    bytes4 constant BLOCK_SELECTOR = bytes4(keccak256("processBlock(address,bytes)"));
    bytes4 constant UNBLOCK_SELECTOR = bytes4(keccak256("processUnblock(address,bytes)"));
    bytes4 constant FOLLOW_RULES_CHANGE_SELECTOR =
        bytes4(keccak256("processFollowRulesChange(address,address[],bytes)"));
}
