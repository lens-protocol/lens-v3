// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownership} from "./../../diamond/Ownership.sol";
import {IRoleBasedAccessControl} from "./IRoleBasedAccessControl.sol";
import {Events} from "./../../types/Events.sol";

contract AddressBasedAccessControl is Ownership, IRoleBasedAccessControl {
    mapping(address => mapping(uint256 => AccessPermission)) internal _globalAccess;
    mapping(address => mapping(address => mapping(uint256 => AccessPermission))) internal _scopedAccess;

    constructor(address owner) Ownership(owner) {
        emit Events.Lens_Contract_Deployed(
            "access-control", "lens.access-control.address-based", "access-control", "lens.access-control.address-based"
        );
    }

    function hasAccess(address account, address resourceLocation, uint256 resourceId)
        external
        view
        override
        returns (bool)
    {
        // `_getScopedAccess` always returns AccessPermission.GRANTED for `_owner`.
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

    function grantRole(address account, uint256 roleId) external pure override {
        // Roles are already pre-assigned. Reverts on every attempt except when it matches the already assigned role.
        require(roleId == _addressToRoleId(account));
    }

    function revokeRole(address, /* account */ uint256 /* roleId */ ) external pure override {
        revert();
    }

    function hasRole(address account, uint256 roleId) external pure override returns (bool) {
        return roleId == _addressToRoleId(account);
    }

    // Note: We allow to deny access to current owner. It will not change the access while it is still the owner,
    // but it will impact right after transferring the ownership.
    function setGlobalAccess(
        uint256 roleId,
        uint256 resourceId,
        AccessPermission accessPermission,
        bytes calldata /* data */
    ) external override onlyOwner {
        require(_isValidRoleId(roleId), "Invalid roleId");
        _globalAccess[_roleIdToAddress(roleId)][resourceId] = accessPermission;
    }

    // Note: We allow to deny access to current owner. It will not change the access while it is still the owner,
    // but it will impact right after transferring the ownership.
    function setScopedAccess(
        uint256 roleId,
        address resourceLocation,
        uint256 resourceId,
        AccessPermission accessPermission,
        bytes calldata /* data */
    ) external override onlyOwner {
        require(_isValidRoleId(roleId), "Invalid roleId");
        _scopedAccess[_roleIdToAddress(roleId)][resourceLocation][resourceId] = accessPermission;
    }

    function getGlobalAccess(uint256 roleId, uint256 resourceId) external view override returns (AccessPermission) {
        if (!_isValidRoleId(roleId)) {
            return AccessPermission.UNDEFINED;
        }
        return _getGlobalAccess(_roleIdToAddress(roleId), resourceId);
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
        if (!_isValidRoleId(roleId)) {
            return AccessPermission.UNDEFINED;
        }
        return _getScopedAccess(_roleIdToAddress(roleId), resourceLocation, resourceId);
    }

    function getScopedAccess(address account, address resourceLocation, uint256 resourceId)
        external
        view
        override
        returns (AccessPermission)
    {
        return _getScopedAccess(account, resourceLocation, resourceId);
    }

    function _getGlobalAccess(address account, uint256 resourceId) internal view returns (AccessPermission) {
        if (_owner == account) {
            return AccessPermission.GRANTED;
        } else {
            return _globalAccess[account][resourceId];
        }
    }

    function _getScopedAccess(address account, address resourceLocation, uint256 resourceId)
        internal
        view
        returns (AccessPermission)
    {
        if (_owner == account) {
            return AccessPermission.GRANTED;
        } else {
            return _scopedAccess[account][resourceLocation][resourceId];
        }
    }

    function _addressToRoleId(address account) internal pure returns (uint256) {
        return uint256(uint160(account));
    }

    function _roleIdToAddress(uint256 roleId) internal pure returns (address) {
        require(_isValidRoleId(roleId), "Invalid roleId");
        return address(uint160(roleId));
    }

    function _isValidRoleId(uint256 roleId) internal pure returns (bool) {
        // In this implementation roles are address-based, so the biggest possible roleId is the maximum uint160 value.
        return roleId <= type(uint160).max;
    }
}
