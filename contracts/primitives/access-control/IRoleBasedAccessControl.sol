// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "./IAccessControl.sol";

// TODO: Should we add `bytes data` param to the `hasAccess`? For more complex logic like providing admin signatures.
interface IRoleBasedAccessControl is IAccessControl {
    event Lens_AccessControl_RoleGranted(address indexed account, uint256 indexed roleId);
    event Lens_AccessControl_RoleRevoked(address indexed account, uint256 indexed roleId);
    event Lens_AccessControl_GlobalAccessSet(
        uint256 indexed roleId, uint256 indexed resourceId, AccessPermission indexed accessPermission
    );
    // TODO: accessPermission param should also be indexed, maybe (resourceLocation, resourceId) should be a tuple type
    event Lens_AccessControl_ScopedAccessSet(
        uint256 indexed roleId,
        address indexed resourceLocation,
        uint256 indexed resourceId,
        AccessPermission accessPermission
    );

    enum AccessPermission {
        UNDEFINED,
        GRANTED,
        DENIED
    }

    // Role functions
    function grantRole(address account, uint256 roleId) external;

    function revokeRole(address account, uint256 roleId) external;

    function hasRole(address account, uint256 roleId) external view returns (bool);

    // Resource access permissions functions - Global
    function setGlobalAccess(uint256 roleId, uint256 resourceId, AccessPermission accessPermission, bytes calldata data)
        external;

    // Resource access permissions functions - Scoped (location is address based)
    function setScopedAccess(
        uint256 roleId,
        address resourceLocation,
        uint256 resourceId,
        AccessPermission accessPermission,
        bytes calldata data
    ) external;

    // These are not meant to be used to check access, but to query internal configuration state instead.
    function getGlobalAccess(uint256 roleId, uint256 resourceId) external view returns (AccessPermission);

    function getGlobalAccess(address account, uint256 resourceId) external view returns (AccessPermission);

    function getScopedAccess(uint256 roleId, address resourceLocation, uint256 resourceId)
        external
        view
        returns (AccessPermission);

    function getScopedAccess(address account, address resourceLocation, uint256 resourceId)
        external
        view
        returns (AccessPermission);
}
