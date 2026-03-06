// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

interface ILock {
    /**
     * @dev Returns true if locked, false if not.
     */
    function isLocked() external view returns (bool);
}
