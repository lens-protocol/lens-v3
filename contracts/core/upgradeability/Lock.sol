// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {ILock} from "contracts/core/interfaces/ILock.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract Lock is Ownable2Step, ILock {
    event LockStatusSet(bool indexed locked);

    bool internal _locked;

    constructor(address owner, bool locked) Ownable2Step() {
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
