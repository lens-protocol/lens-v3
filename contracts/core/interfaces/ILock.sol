// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

interface ILock {
    /**
     * @dev Returns true if locked, false if not.
     */
    function isLocked() external view returns (bool);
}
