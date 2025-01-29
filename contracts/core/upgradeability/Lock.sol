// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {ILock} from "contracts/core/interfaces/ILock.sol";
import {Ownable} from "contracts/core/access/Ownable.sol";
import {EventEmitterEarly} from "contracts/migration/EventEmitterEarly.sol";

contract Lock is Ownable, ILock, EventEmitterEarly {
    event Lens_Lock_LockStatusSet(bool indexed locked);
    event Lens_Lock_LockStatusSet(address indexed target, bool indexed locked);

    bool internal _areAllAddressesUnlocked;
    mapping(address => bool) internal _isAddressUnlocked;

    constructor(address owner, bool locked) Ownable() {
        _transferOwnership(owner);
        _setLockStatus(locked);
    }

    function isLocked() external view override returns (bool) {
        if (_areAllAddressesUnlocked) {
            return false;
        } else {
            return !_isAddressUnlocked[msg.sender];
        }
    }

    function setLockStatus(bool locked) external onlyOwner {
        _setLockStatus(locked);
    }

    // Only to unlock specific addresses before the global lock is released.
    function setLockStatusForAddress(address target, bool locked) external onlyOwner {
        _isAddressUnlocked[target] = !locked;
        emit Lens_Lock_LockStatusSet(target, locked);
    }

    function _setLockStatus(bool locked) internal {
        _areAllAddressesUnlocked = !locked;
        emit Lens_Lock_LockStatusSet(locked);
    }
}
