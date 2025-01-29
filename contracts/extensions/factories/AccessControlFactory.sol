// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IRoleBasedAccessControl} from "contracts/core/interfaces/IRoleBasedAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "contracts/extensions/access/OwnerAdminOnlyAccessControl.sol";
import {ILock} from "contracts/core/interfaces/ILock.sol";

contract AccessControlFactory {
    /// @custom:keccak lens.role.Admin
    uint256 constant ADMIN_ROLE_ID = uint256(0xfcbeadd75a96b5f8140d8c80f7c8d81ccbd7c4caa9592217bc8936b9eaabee75);

    event Lens_AccessControlFactory_OwnerAdminDeployment(address indexed accessControl, address owner);

    address immutable LOCK;

    constructor(address lock) {
        LOCK = lock;
        ILock(LOCK).isLocked(); // Aims to verify the given address follows ILock interface
    }

    function deployOwnerAdminOnlyAccessControl(address owner, address[] calldata admins)
        external
        returns (IRoleBasedAccessControl)
    {
        OwnerAdminOnlyAccessControl accessControl = new OwnerAdminOnlyAccessControl({owner: address(this), lock: LOCK});
        emit Lens_AccessControlFactory_OwnerAdminDeployment(address(accessControl), owner);
        for (uint256 i = 0; i < admins.length; i++) {
            accessControl.grantRole(admins[i], ADMIN_ROLE_ID);
        }
        accessControl.transferOwnership(owner);
        return accessControl;
    }
}
