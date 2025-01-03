// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {ILock} from "contracts/core/interfaces/ILock.sol";

contract ProxyAdminLock is ILock {
    address internal _owner; // TODO: Make it Ownable
    bool internal _restricted;

    constructor(address owner, bool restricted) {
        _owner = owner;
        _restricted = restricted;
        // Event
    }

    function setRestricted(bool restricted) external {
        require(msg.sender == _owner);
        _restricted = restricted;
        // Event
    }

    function isRestricted() external view returns (bool) {
        return _restricted;
    }
}
