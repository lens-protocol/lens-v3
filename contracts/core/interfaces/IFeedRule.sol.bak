// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {CreatePostParams, EditPostParams} from "./IFeed.sol";
import {RuleChange} from "./../types/Types.sol";

interface IFeedRule {
    function configure(bytes calldata data) external;

    function processCreatePost(
        uint256 postId,
        CreatePostParams calldata postParams,
        bytes calldata data
    ) external returns (bool);

    function processEditPost(
        uint256 postId,
        EditPostParams calldata editPostParams,
        bytes calldata data
    ) external returns (bool);

    function processPostRuleChanges(
        uint256 postId,
        RuleChange[] calldata ruleChanges,
        bytes calldata data
    ) external returns (bool);
}
