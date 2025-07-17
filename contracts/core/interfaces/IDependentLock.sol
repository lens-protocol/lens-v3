// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

interface IDependentLock {
    /**
     * @dev Returns true if locked for the given address, false if not.
     */
    function isLocked(address addr) external view returns (bool);
}
