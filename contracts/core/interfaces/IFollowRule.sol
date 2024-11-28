// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

interface IFollowRule {
    function configure(address account, bytes calldata data) external;

    function processFollow(
        address followerAccount,
        address accountToFollow,
        bytes calldata data
    ) external returns (bool);
}
