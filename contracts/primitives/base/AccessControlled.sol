// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "./../access-control/IAccessControl.sol";
import {AccessControlLib} from "./../libraries/AccessControlLib.sol";

contract AccessControlled {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Lens_PermissonId_Available(uint256 indexed permissionId, string name);
    event Lens_AccessControlAdded(address indexed accessControl);
    event Lens_AccessControlUpdated(address indexed accessControl);

    uint256 constant SET_ACCESS_CONTROL_PID = uint256(keccak256("SET_ACCESS_CONTROL"));

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
        _setAccessControl(address(accessControl));
    }

    modifier requireAccess(uint256 permissionId) {
        _requireAccess(msg.sender, permissionId);
        _;
    }

    function _emitPIDs() internal virtual {
        emit Lens_PermissonId_Available(SET_ACCESS_CONTROL_PID, "SET_ACCESS_CONTROL");
    }

    function _requireAccess(address account, uint256 permissionId) internal view {
        _accessControl().requireAccess(account, permissionId);
    }

    function _hasAccess(address account, uint256 permissionId) internal view returns (bool) {
        return _accessControl().hasAccess(account, permissionId);
    }

    // Access Controlled Functions
    function setAccessControl(IAccessControl newAccessControl) external virtual {
        _accessControl().requireAccess(msg.sender, SET_ACCESS_CONTROL_PID);
        newAccessControl.verifyHasAccessFunction();
        _setAccessControl(address(newAccessControl));
    }

    // Internal functions

    function _accessControl() internal view returns (IAccessControl) {
        return IAccessControl($accessControlledStorage().accessControl);
    }

    function _setAccessControl(address newAccessControl) internal {
        address oldAccessControl = $accessControlledStorage().accessControl;
        $accessControlledStorage().accessControl = newAccessControl;
        if (oldAccessControl == address(0)) {
            emit Lens_AccessControlAdded(newAccessControl);
        } else {
            emit Lens_AccessControlUpdated(newAccessControl);
        }
    }

    // Getters

    function getAccessControl() external view returns (IAccessControl) {
        return _accessControl();
    }
}
