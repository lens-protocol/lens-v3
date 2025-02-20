// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

interface IOwnable {
    function transferOwnership(address newOwner) external;

    function owner() external view returns (address);
}
