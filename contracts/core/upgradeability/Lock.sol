// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {ILock} from "contracts/core/interfaces/ILock.sol";
import {Ownable} from "contracts/core/access/Ownable.sol";
import {EventEmitterEarly} from "contracts/migration/EventEmitterEarly.sol";

contract Lock is Ownable, ILock, EventEmitterEarly {
    event LockStatusSet(bool indexed locked);

    bool internal _locked;

    constructor(address owner, bool locked) Ownable() {
        _transferOwnership(owner);
        _setLockStatus(locked);
    }

    function isLocked() external view override returns (bool) {
        return _locked;
    }

    function setLockStatus(bool locked) external onlyOwner {
        _setLockStatus(locked);
    }

    function _setLockStatus(bool locked) internal {
        _locked = locked;
        emit LockStatusSet(locked);
    }
}
