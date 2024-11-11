// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CreatePostParams, EditPostParams} from "./IFeed.sol";
import {RuleConfiguration} from "./../types/Types.sol";

interface IFeedRule {
    function configure(bytes calldata data) external;

    function processCreatePost(uint256 postId, CreatePostParams calldata postParams, bytes calldata data)
        external
        returns (bool);

    function processEditPost(uint256 postId, EditPostParams calldata editPostParams, bytes calldata data)
        external
        returns (bool);

    function processPostRulesChanged(uint256 postId, RuleConfiguration[] calldata newPostRules, bytes calldata data)
        external
        returns (bool);
}
