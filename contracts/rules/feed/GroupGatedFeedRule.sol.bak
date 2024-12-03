// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {CreatePostParams, EditPostParams} from "./../../core/interfaces/IFeed.sol";
import {IFeedRule} from "./../../core/interfaces/IFeedRule.sol";
import {RuleChange} from "./../../core/types/Types.sol";
import {IGroup} from "./../../core/interfaces/IGroup.sol";

contract GroupGatedFeedRule is IFeedRule {
    mapping(address => address) internal _groupGate;

    function configure(bytes calldata data) external override {
        _groupGate[msg.sender] = abi.decode(data, (address));
    }

    function processCreatePost(
        uint256, /* postId */
        CreatePostParams calldata postParams,
        bytes calldata /* data */
    ) external view override returns (bool) {
        require(IGroup(_groupGate[msg.sender]).getMembershipId(postParams.author) != 0, "NotAMember()");
        return true;
    }

    function processEditPost(
        uint256, /* postId */
        EditPostParams calldata, /* editPostParams */
        bytes calldata /* data */
    ) external pure override returns (bool) {
        return false;
    }

    function processPostRuleChanges(
        uint256, /* postId */
        RuleChange[] calldata, /* ruleChanges */
        bytes calldata /* data */
    ) external pure override returns (bool) {
        return false;
    }
}
