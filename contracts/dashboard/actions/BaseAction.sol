// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

abstract contract BaseAction {
    address immutable ACTION_HUB;

    modifier onlyActionHub() {
        require(msg.sender == ACTION_HUB);
        _;
    }

    constructor(
        address actionHub
    ) {
        ACTION_HUB = actionHub;
    }
}
