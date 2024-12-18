// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {CreatePostParams, EditPostParams} from "./IFeed.sol";
import {KeyValue} from "./../types/Types.sol";

interface IPostRule {
    function configure(bytes32 configSalt, uint256 postId, KeyValue[] calldata ruleParams) external;

    function processCreatePost(
        bytes32 configSalt,
        uint256 rootPostId,
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;

    function processEditPost(
        bytes32 configSalt,
        uint256 rootPostId,
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;
}
