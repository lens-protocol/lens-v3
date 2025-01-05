// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {Events} from "contracts/core/types/Events.sol";
import {RoleBasedAccessControl} from "contracts/core/access/RoleBasedAccessControl.sol";
import {Access} from "contracts/core/interfaces/IRoleBasedAccessControl.sol";

contract OwnerAdminOnlyAccessControl is RoleBasedAccessControl {
    /// @custom:keccak lens.role.Admin
    uint256 constant ADMIN_ROLE_ID = uint256(0xfcbeadd75a96b5f8140d8c80f7c8d81ccbd7c4caa9592217bc8936b9eaabee75);
    /// @custom:keccak lens.contract.AccessControl.OwnerAdminOnlyAccessControl
    bytes32 constant OWNER_ADMIN_ONLY_CONTRACT_TYPE = 0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb;

    constructor(address owner) RoleBasedAccessControl(owner) {
        _setAccess(ADMIN_ROLE_ID, ANY_CONTRACT_ADDRESS, ANY_PERMISSION_ID, Access.GRANTED);
    }

    function _beforeGrantingRole(address account, uint256 roleId) internal virtual override {
        require(roleId == ADMIN_ROLE_ID, "You cannot grant other roles than ADMIN");
        super._beforeGrantingRole(account, roleId);
    }

    function _beforeSettingAccess(
        uint256, /*roleId*/
        address, /*contractAddress*/
        uint256, /*permissionId*/
        Access /*access*/
    ) internal virtual override {
        revert();
    }

    function getType() external pure virtual override returns (bytes32) {
        return OWNER_ADMIN_ONLY_CONTRACT_TYPE;
    }

    function _emitLensContractDeployedEvent() internal virtual override {
        emit Events.Lens_Contract_Deployed( // TODO: Fix!
            "access-control",
            "lens.access-control.owner-admin-only-access-control",
            "access-control",
            "lens.access-control.owner-admin-only-access-control"
        );
    }
}
