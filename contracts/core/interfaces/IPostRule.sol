// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

// TODO: We do not have native referrals here, should we add them?
interface IPostRule {
    function configure(uint256 postId, bytes calldata data) external;

    function processQuote(uint256 rootPostId, uint256 quotedPostId, uint256 postId, bytes calldata data)
        external
        returns (bool);

    function processReply(uint256 rootPostId, uint256 repliedPostId, uint256 postId, bytes calldata data)
        external
        returns (bool);

    function processRepost(uint256 rootPostId, uint256 repostedPostId, uint256 postId, bytes calldata data)
        external
        returns (bool);
}
