// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";

enum Access {
    UNDEFINED,
    GRANTED,
    DENIED
}

struct Role {
    address account;
    uint256 roleId;
}

interface IRoleBasedAccessControl is IAccessControl {
    event Lens_AccessControl_RoleGranted(address indexed account, uint256 indexed roleId);
    event Lens_AccessControl_RoleRevoked(address indexed account, uint256 indexed roleId);

    event Lens_AccessControl_AccessAdded(
        uint256 indexed roleId, address indexed contractAddress, uint256 indexed permissionId, bool granted
    );
    event Lens_AccessControl_AccessUpdated(
        uint256 indexed roleId, address indexed contractAddress, uint256 indexed permissionId, bool granted
    );
    event Lens_AccessControl_AccessRemoved(
        uint256 indexed roleId, address indexed contractAddress, uint256 indexed permissionId
    );

    // Role functions
    function grantRole(address account, uint256 roleId) external;

    function revokeRole(address account, uint256 roleId) external;

    function grantRoles(Role[] calldata roles) external;

    function revokeRoles(Role[] calldata roles) external;

    function hasRole(address account, uint256 roleId) external view returns (bool);

    // Access functions
    function setAccess(uint256 roleId, address contractAddress, uint256 permissionId, Access access) external;

    function getAccess(uint256 roleId, address contractAddress, uint256 permissionId) external view returns (Access);
}
