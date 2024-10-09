// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRoleBasedAccessControl} from "./IRoleBasedAccessControl.sol";
import {Events} from "./../../types/Events.sol";

/**
 * This Access Control:
 * - Allows to add any custom role.
 * - Has two special pre-defined roles with pre-defined permissions: Owner and Admin.
 * - There is only a single Owner.
 * - There can be multiple Admins.
 * - Owners can do everything.
 * - Admins can do everything except changing roles (adding or removing Admins or Owners).
 * - When some account has many roles, access permission is the most permissive one (i.e. granted-overrides strategy).
 */
contract RoleBasedAccessControl is IRoleBasedAccessControl {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 immutable OWNER_ROLE_ID = uint256(keccak256("OWNER"));
    uint256 immutable ADMIN_ROLE_ID = uint256(keccak256("ADMIN"));

    address internal _owner;
    mapping(address => bool) internal _isAdmin;
    mapping(address => uint256[]) internal _roles;
    mapping(uint256 => mapping(address => mapping(uint256 => AccessPermission))) internal _scopedAccess;
    mapping(uint256 => mapping(uint256 => AccessPermission)) internal _globalAccess;

    constructor(address owner) {
        emit Events.Lens_Contract_Deployed(
            "access-control", "lens.access-control.owner-admin", "access-control", "lens.access-control.owner-admin"
        );
        _owner = owner;
        emit Lens_AccessControl_RoleGranted(owner, OWNER_ROLE_ID);
    }

    function transferOwnership(address newOwner) external {
        address oldOwner = _owner;
        require(msg.sender == _owner);
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function hasAccess(address account, address resourceLocation, uint256 resourceId)
        external
        view
        override
        returns (bool)
    {
        // `_getScopedAccess` always returns AccessPermission.GRANTED for Owner and Admins.
        AccessPermission scopedAccess = _getScopedAccess(account, resourceLocation, resourceId);
        if (scopedAccess == AccessPermission.GRANTED) {
            return true;
        } else if (scopedAccess == AccessPermission.DENIED) {
            return false;
        } else {
            // scopedAccess == AccessPermission.UNDEFINED, so it depends exclusively on the global access.
            return _getGlobalAccess(account, resourceId) == AccessPermission.GRANTED;
        }
    }

    function grantRole(address account, uint256 roleId) external override {
        require(msg.sender == _owner);
        require(account != _owner);
        if (roleId == OWNER_ROLE_ID) {
            revert();
        } else if (roleId == ADMIN_ROLE_ID) {
            _isAdmin[account] = true;
        } else {
            require(!_hasCustomRole(account, roleId));
            _roles[account].push(roleId);
        }
        emit Lens_AccessControl_RoleGranted(account, roleId);
    }

    function revokeRole(address account, uint256 roleId) external override {
        require(msg.sender == _owner);
        require(account != _owner);
        if (roleId == OWNER_ROLE_ID) {
            revert();
        } else if (roleId == ADMIN_ROLE_ID) {
            _isAdmin[account] = false;
        } else {
            uint256 accountRolesLength = _roles[account].length;
            require(accountRolesLength > 0);
            uint256 roleIndex = 0;
            while (roleIndex < accountRolesLength) {
                if (_roles[account][roleIndex] == roleId) {
                    break;
                } else {
                    roleIndex++;
                }
            }
            require(roleIndex < accountRolesLength); // Index must be found before reaching the end of the array
            _roles[account][roleIndex] = _roles[account][accountRolesLength - 1];
            _roles[account].pop();
        }
        emit Lens_AccessControl_RoleRevoked(account, roleId);
    }

    function hasRole(address account, uint256 roleId) external view override returns (bool) {
        if (roleId == ADMIN_ROLE_ID) {
            return account == _owner;
        } else if (roleId == ADMIN_ROLE_ID) {
            return _isAdmin[account];
        } else {
            return _hasCustomRole(account, roleId);
        }
    }

    function setGlobalAccess(
        uint256 roleId,
        uint256 resourceId,
        AccessPermission accessPermission,
        bytes calldata /* data */
    ) external override {
        require(msg.sender == _owner);
        require(roleId != OWNER_ROLE_ID && roleId != ADMIN_ROLE_ID);
        _globalAccess[roleId][resourceId] = accessPermission;
        emit Lens_AccessControl_GlobalAccessSet(roleId, resourceId, accessPermission);
    }

    function setScopedAccess(
        uint256 roleId,
        address resourceLocation,
        uint256 resourceId,
        AccessPermission accessPermission,
        bytes calldata /* data */
    ) external override {
        require(msg.sender == _owner);
        require(roleId != OWNER_ROLE_ID && roleId != ADMIN_ROLE_ID);
        _scopedAccess[roleId][resourceLocation][resourceId] = accessPermission;
        emit Lens_AccessControl_ScopedAccessSet(roleId, resourceLocation, resourceId, accessPermission);
    }

    function getGlobalAccess(uint256 roleId, uint256 resourceId) external view override returns (AccessPermission) {
        return _globalAccess[roleId][resourceId];
    }

    function getGlobalAccess(address account, uint256 resourceId) external view override returns (AccessPermission) {
        return _getGlobalAccess(account, resourceId);
    }

    function getScopedAccess(uint256 roleId, address resourceLocation, uint256 resourceId)
        external
        view
        override
        returns (AccessPermission)
    {
        return _scopedAccess[roleId][resourceLocation][resourceId];
    }

    function getScopedAccess(address account, address resourceLocation, uint256 resourceId)
        external
        view
        override
        returns (AccessPermission)
    {
        return _getScopedAccess(account, resourceLocation, resourceId);
    }

    function _hasCustomRole(address account, uint256 roleId) internal view returns (bool) {
        for (uint256 i = 0; i < _roles[account].length; i++) {
            if (_roles[account][i] == roleId) {
                return true;
            }
        }
        return false;
    }

    function _getScopedAccess(address account, address resourceLocation, uint256 resourceId)
        internal
        view
        returns (AccessPermission)
    {
        if (_owner == account || _isAdmin[account]) {
            return AccessPermission.GRANTED;
        } else {
            AccessPermission accessPermission = AccessPermission.UNDEFINED;
            for (uint256 i = 0; i < _roles[account].length; i++) {
                if (_scopedAccess[_roles[account][i]][resourceLocation][resourceId] == AccessPermission.DENIED) {
                    accessPermission = AccessPermission.DENIED;
                } else if (_scopedAccess[_roles[account][i]][resourceLocation][resourceId] == AccessPermission.GRANTED)
                {
                    return AccessPermission.GRANTED;
                }
            }
            return accessPermission;
        }
    }

    function _getGlobalAccess(address account, uint256 resourceId) internal view returns (AccessPermission) {
        if (_owner == account || _isAdmin[account]) {
            return AccessPermission.GRANTED;
        } else {
            AccessPermission accessPermission = AccessPermission.UNDEFINED;
            for (uint256 i = 0; i < _roles[account].length; i++) {
                if (_globalAccess[_roles[account][i]][resourceId] == AccessPermission.DENIED) {
                    accessPermission = AccessPermission.DENIED;
                } else if (_globalAccess[_roles[account][i]][resourceId] == AccessPermission.GRANTED) {
                    return AccessPermission.GRANTED;
                }
            }
            return accessPermission;
        }
    }
}
