// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreatePostParams, EditPostParams} from "./IFeed.sol";
import {RuleConfiguration} from "./../../types/Types.sol";

interface IFeedRule {
    function configure(bytes calldata data) external;

    function processCreatePost(
        uint256 postId,
        uint256 localSequentialId,
        CreatePostParams calldata postParams,
        bytes calldata data
    ) external;

    function processEditPost(
        uint256 postId,
        uint256 localSequentialId,
        EditPostParams calldata newPostParams,
        bytes calldata data
    ) external;

    function processDeletePost(uint256 postId, uint256 localSequentialId, bytes calldata feedRulesData) external;

    function processPostRulesChanged(
        uint256 postId,
        uint256 localSequentialId,
        RuleConfiguration[] calldata newPostRules,
        bytes calldata data
    ) external;

    // TODO: Do we need these global quote/parent rules? Or they exist only per-post?
    // function processQuotes
    // function processParents
}
