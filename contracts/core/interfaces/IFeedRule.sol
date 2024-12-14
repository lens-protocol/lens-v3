// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {CreatePostParams, EditPostParams} from "./IFeed.sol";
import {KeyValue, RuleChange} from "./../types/Types.sol";

interface IFeedRule {
    function configure(bytes4 ruleSelector, bytes32 salt, KeyValue[] calldata ruleConfigurationParams) external;

    function processCreatePost(
        bytes32 configSalt,
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleExecutionParams
    ) external;

    function processEditPost(
        bytes32 configSalt,
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleExecutionParams
    ) external;

    function processRemovePost(
        bytes32 configSalt,
        uint256 postId,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleExecutionParams
    ) external;

    function processPostRuleChanges(
        bytes32 configSalt,
        uint256 postId,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata ruleExecutionParams
    ) external;
}
