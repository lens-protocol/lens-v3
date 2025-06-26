// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Ownable} from "contracts/core/access/Ownable.sol";
import {MockUniversal} from "test/mocks/MockUniversal.sol";

contract MockOwnableUniversal is MockUniversal, Ownable {
    bool _mockOwnerOnNextCall;
    address _ownerToMock;

    function mockOwner(address newOwner) external {
        _transferOwnership(newOwner);
    }

    function mockOwnerOnNextCall(address newOwner) external {
        _mockOwnerOnNextCall = true;
        _ownerToMock = newOwner;
    }

    function _fallback() internal override {
        super._fallback();
        if (_mockOwnerOnNextCall) {
            delete _mockOwnerOnNextCall;
            _transferOwnership(_ownerToMock);
        }
    }
}
