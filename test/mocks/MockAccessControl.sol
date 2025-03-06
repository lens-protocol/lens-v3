// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IAccessControl} from "@core/interfaces/IAccessControl.sol";

contract MockAccessControl is IAccessControl {
    function testMockAccessControl() public {
        // Prevents being included in the foundry coverage report
    }

    mapping(address => mapping(address => bool)) _mockedCanChangeAccessControl;
    mapping(address => mapping(address => mapping(uint256 => bool))) _mockedAccess;

    function getType() external pure override returns (bytes32) {
        return keccak256("lens.contract.AccessControl.MockAccessControl");
    }

    function canChangeAccessControl(address account, address contractAddress) external view override returns (bool) {
        return _mockedCanChangeAccessControl[account][contractAddress];
    }

    function hasAccess(address account, address contractAddress, uint256 permissionId)
        external
        view
        override
        returns (bool)
    {
        return _mockedAccess[account][contractAddress][permissionId];
    }

    function mockCanChangeAccessControl(address account, address contractAddress, bool canChange) external {
        _mockedCanChangeAccessControl[account][contractAddress] = canChange;
    }

    function mockAccess(address account, address contractAddress, uint256 permissionId, bool access) external {
        _mockedAccess[account][contractAddress][permissionId] = access;
    }
}
