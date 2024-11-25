// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../interfaces/IAccessControl.sol";
import {AccessControlLib} from "./../libraries/AccessControlLib.sol";

contract AccessControlled {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Lens_AccessControlAdded(address indexed accessControl, bytes32 indexed accessControlType);
    event Lens_AccessControlUpdated(address indexed accessControl, bytes32 indexed accessControlType);

    struct AccessControlledStorage {
        address accessControl;
    }

    // keccak256('lens.access.controlled.storage')
    bytes32 constant ACCESS_CONTROLLED_STORAGE_SLOT = 0x9211c0302e22d62530da4939528366f76a6ad7e8fc8b35b47780fadbea21baac;

    function $accessControlledStorage() private pure returns (AccessControlledStorage storage _storage) {
        assembly {
            _storage.slot := ACCESS_CONTROLLED_STORAGE_SLOT
        }
    }

    constructor(IAccessControl accessControl) {
        accessControl.verifyHasAccessFunction();
        _setAccessControl(accessControl);
    }

    modifier requireAccess(uint256 permissionId) {
        _requireAccess(msg.sender, permissionId);
        _;
    }

    function _emitPIDs() internal virtual {}

    function _requireAccess(address account, uint256 permissionId) internal view {
        _accessControl().requireAccess(account, permissionId);
    }

    function _hasAccess(address account, uint256 permissionId) internal view returns (bool) {
        return _accessControl().hasAccess(account, permissionId);
    }

    // Access Controlled Functions
    function setAccessControl(IAccessControl newAccessControl) external virtual {
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

    function getAccessControl() external view returns (IAccessControl) {
        return _accessControl();
    }
}
