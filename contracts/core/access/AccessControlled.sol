// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {IAccessControlled} from "contracts/core/interfaces/IAccessControlled.sol";

abstract contract AccessControlled is IAccessControlled {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Lens_AccessControlAdded(address indexed accessControl, bytes32 indexed accessControlType);
    event Lens_AccessControlUpdated(address indexed accessControl, bytes32 indexed accessControlType);

    struct AccessControlledStorage {
        address accessControl;
    }

    /// @custom:keccak lens.storage.AccessControlledStorage.AccessControlledStorage
    bytes32 constant STORAGE__ACCESS_CONTROLLED = 0xbd033a0ffbb1596134cd289270549cdbb5543523671bd5bbfcdc89a3f6decd75;

    function $accessControlledStorage() private pure returns (AccessControlledStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__ACCESS_CONTROLLED
        }
    }

    function _initialize(IAccessControl accessControl) internal {
        accessControl.verifyHasAccessFunction();
        _setAccessControl(accessControl);
    }

    function _emitPIDs() internal virtual {}

    function _requireAccess(address account, uint256 permissionId) internal view {
        _accessControl().requireAccess(account, permissionId);
    }

    function _hasAccess(address account, uint256 permissionId) internal view returns (bool) {
        return _accessControl().hasAccess(account, permissionId);
    }

    // Access Controlled Functions
    function setAccessControl(IAccessControl newAccessControl) external {
        _accessControl().requireCanChangeAccessControl(msg.sender);
        newAccessControl.verifyHasAccessFunction();
        _setAccessControl(newAccessControl);
    }

    // Internal functions

    function _accessControl() internal view returns (IAccessControl) {
        return IAccessControl($accessControlledStorage().accessControl);
    }

    function _setAccessControl(IAccessControl newAccessControl) internal {
        address oldAccessControl = $accessControlledStorage().accessControl;
        $accessControlledStorage().accessControl = address(newAccessControl);
        if (oldAccessControl == address(0)) {
            emit Lens_AccessControlAdded(address(newAccessControl), newAccessControl.getType());
        } else {
            emit Lens_AccessControlUpdated(address(newAccessControl), newAccessControl.getType());
        }
    }

    // Getters

    function getAccessControl() external view override returns (IAccessControl) {
        return _accessControl();
    }
}
