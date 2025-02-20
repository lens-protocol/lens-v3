// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Access, IRoleBasedAccessControl, Role} from "contracts/core/interfaces/IRoleBasedAccessControl.sol";
import {Ownable} from "contracts/core/access/Ownable.sol";
import {Events} from "contracts/core/types/Events.sol";
import {Errors} from "contracts/core/types/Errors.sol";

/**
 * This Access Control:
 * - Has a single special pre-defined role, the Owner role, with pre-defined permissions.
 * - Allows to have only a single Owner.
 * - Pre-establishes that the Owner can do everything.
 * - Allows to add any extra roles.
 * - Has zero-values as wildcards for both contract addresses scopes and permission IDs (i.e. 0 means ANY).
 * - Chain of lookup: scoped permission > scoped contract > global permission > global contract (i.e. scoped-overrides strategy).
 * - More specific (and less wildcards) scoped permissions have precedence over more general ones.
 * - Within an specific role the denied-overrides strategy is applied (in case of same amount of wildcards).
 * - When some account has many roles, the final permission is the most permissive one (i.e. granted-overrides strategy).
 */
contract RoleBasedAccessControl is Ownable, IRoleBasedAccessControl {
    address internal constant ANY_CONTRACT_ADDRESS = address(0);
    uint256 internal constant ANY_PERMISSION_ID = uint256(0);
    /// @custom:keccak lens.role.Owner
    uint256 constant OWNER_ROLE_ID = uint256(0x441b0c1da21837a189de2bb219f231a98e08a545e9ede0b2874dec4807e57e7e);
    /// @custom:keccak lens.contract.AccessControl.RoleBasedAccessControl
    bytes32 constant CONTRACT_TYPE = 0xd7f02d8d0f478fc8e4dfbe64bafebbee03e9d359c4395bdbf35858b495f3daaa;

    mapping(address => uint256[]) internal _roles;
    mapping(uint256 => mapping(address => mapping(uint256 => Access))) internal _access;

    constructor(address owner) {
        _emitLensContractDeployedEvent();
        _grantRole(owner, OWNER_ROLE_ID);
        _setAccess(OWNER_ROLE_ID, ANY_CONTRACT_ADDRESS, ANY_PERMISSION_ID, Access.GRANTED);
        _transferOwnership(owner);
    }

    function transferOwnership(address newOwner) public virtual override {
        _revokeRole(owner(), OWNER_ROLE_ID);
        _grantRole(newOwner, OWNER_ROLE_ID);
        super.transferOwnership(newOwner);
    }

    function getType() external pure virtual override returns (bytes32) {
        return CONTRACT_TYPE;
    }

    function canChangeAccessControl(address account, address /* contractAddress */ )
        external
        view
        virtual
        override
        returns (bool)
    {
        return account == owner();
    }

    function hasAccess(address account, address contractAddress, uint256 permissionId)
        external
        view
        virtual
        override
        returns (bool)
    {
        return _hasAccess(account, contractAddress, permissionId);
    }

    function grantRoles(Role[] calldata roles) external virtual override {
        for (uint256 i = 0; i < roles.length; i++) {
            address account = roles[i].account;
            uint256 roleId = roles[i].roleId;
            _beforeGrantingRole(account, roleId);
            _grantRole(account, roleId);
        }
    }

    function revokeRoles(Role[] calldata roles) external virtual override {
        for (uint256 i = 0; i < roles.length; i++) {
            address account = roles[i].account;
            uint256 roleId = roles[i].roleId;
            _beforeRevokingRole(account, roleId);
            _revokeRole(account, roleId);
        }
    }

    function grantRole(address account, uint256 roleId) external virtual override {
        _beforeGrantingRole(account, roleId);
        _grantRole(account, roleId);
    }

    function revokeRole(address account, uint256 roleId) external virtual override {
        _beforeRevokingRole(account, roleId);
        _revokeRole(account, roleId);
    }

    function _beforeGrantingRole(address, /* account */ uint256 roleId) internal virtual onlyOwner {
        require(roleId != OWNER_ROLE_ID, Errors.InvalidParameter());
    }

    function _grantRole(address account, uint256 roleId) internal virtual {
        require(!_hasRole(account, roleId), Errors.RedundantStateChange());
        _roles[account].push(roleId);
        emit Lens_AccessControl_RoleGranted(account, roleId);
    }

    function _beforeRevokingRole(address, /* account */ uint256 roleId) internal virtual onlyOwner {
        require(roleId != OWNER_ROLE_ID, Errors.InvalidParameter());
    }

    function _revokeRole(address account, uint256 roleId) internal virtual {
        uint256 accountRolesLength = _roles[account].length;
        require(accountRolesLength > 0, Errors.RedundantStateChange());
        uint256 roleIndex = 0;
        while (roleIndex < accountRolesLength) {
            if (_roles[account][roleIndex] == roleId) {
                break;
            } else {
                roleIndex++;
            }
        }
        require(roleIndex < accountRolesLength, Errors.RedundantStateChange()); // Index must be found before reaching the end of the array
        _roles[account][roleIndex] = _roles[account][accountRolesLength - 1];
        _roles[account].pop();
        emit Lens_AccessControl_RoleRevoked(account, roleId);
    }

    function hasRole(address account, uint256 roleId) external view override returns (bool) {
        return _hasRole(account, roleId);
    }

    function setAccess(uint256 roleId, address contractAddress, uint256 permissionId, Access access)
        external
        virtual
        override
    {
        _beforeSettingAccess(roleId, contractAddress, permissionId, access);
        // solc-ignore-next-line unreachable
        _setAccess(roleId, contractAddress, permissionId, access);
    }

    function _beforeSettingAccess(
        uint256 roleId,
        address, /* contractAddress */
        uint256, /* permissionId */
        Access /* access */
    ) internal virtual onlyOwner {
        require(roleId != OWNER_ROLE_ID, Errors.InvalidParameter());
    }

    function _setAccess(uint256 roleId, address contractAddress, uint256 permissionId, Access access) internal virtual {
        Access perviousAccess = _access[roleId][contractAddress][permissionId];
        require(access != perviousAccess, Errors.RedundantStateChange());
        _access[roleId][contractAddress][permissionId] = access;
        if (perviousAccess == Access.UNDEFINED) {
            emit Lens_AccessControl_AccessAdded(roleId, contractAddress, permissionId, access == Access.GRANTED);
        } else if (access == Access.UNDEFINED) {
            emit Lens_AccessControl_AccessRemoved(roleId, contractAddress, permissionId);
        } else {
            emit Lens_AccessControl_AccessUpdated(roleId, contractAddress, permissionId, access == Access.GRANTED);
        }
    }

    function _hasAccess(address account, address contractAddress, uint256 permissionId)
        internal
        view
        virtual
        returns (bool)
    {
        require(contractAddress != ANY_CONTRACT_ADDRESS, Errors.InvalidParameter());
        require(permissionId != ANY_PERMISSION_ID, Errors.InvalidParameter());
        for (uint256 i = 0; i < _roles[account].length; i++) {
            if (_hasAccess(_roles[account][i], contractAddress, permissionId)) {
                // GRANTED-overrides strategy
                return true;
            }
        }
        return false;
    }

    function _hasAccess(uint256 roleId, address contractAddress, uint256 permissionId)
        internal
        view
        virtual
        returns (bool)
    {
        Access fullySpecifiedAccess = _access[roleId][contractAddress][permissionId];

        if (fullySpecifiedAccess != Access.UNDEFINED) {
            return fullySpecifiedAccess == Access.GRANTED;
        }

        Access anyPermissionAccess = _access[roleId][contractAddress][ANY_PERMISSION_ID];
        Access anyAddressAccess = _access[roleId][ANY_CONTRACT_ADDRESS][permissionId];

        if (anyPermissionAccess == Access.UNDEFINED && anyAddressAccess == Access.UNDEFINED) {
            return _access[roleId][ANY_CONTRACT_ADDRESS][ANY_PERMISSION_ID] == Access.GRANTED;
        } else {
            // DENIED-overrides strategy
            return anyPermissionAccess != Access.DENIED && anyAddressAccess != Access.DENIED;
        }
    }

    function getAccess(uint256 roleId, address contractAddress, uint256 permissionId)
        external
        view
        virtual
        override
        returns (Access)
    {
        return _access[roleId][contractAddress][permissionId];
    }

    function _hasRole(address account, uint256 roleId) internal view virtual returns (bool) {
        for (uint256 i = 0; i < _roles[account].length; i++) {
            if (_roles[account][i] == roleId) {
                return true;
            }
        }
        return false;
    }

    function _emitLensContractDeployedEvent() internal virtual {
        emit Events.Lens_Contract_Deployed({
            contractType: "lens.contract.AccessControl",
            flavour: "lens.contract.AccessControl.RoleBasedAccessControl"
        });
    }
}
