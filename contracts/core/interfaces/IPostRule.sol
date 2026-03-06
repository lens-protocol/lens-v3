// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";
import {KeyValue} from "contracts/core/types/Types.sol";

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
