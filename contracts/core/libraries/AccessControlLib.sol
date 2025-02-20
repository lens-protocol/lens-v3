// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Errors} from "contracts/core/types/Errors.sol";

library AccessControlLib {
    function requireAccess(address accessControl, address account, address contractAddress, uint256 permissionId)
        internal
        view
    {
        requireAccess(IAccessControl(accessControl), account, contractAddress, permissionId);
    }

    function requireAccess(IAccessControl accessControl, address account, address contractAddress, uint256 permissionId)
        internal
        view
    {
        require(
            accessControl.hasAccess({account: account, contractAddress: contractAddress, permissionId: permissionId}),
            Errors.AccessDenied()
        );
    }

    function requireAccess(address accessControl, address account, uint256 permissionId) internal view {
        requireAccess(IAccessControl(accessControl), account, permissionId);
    }

    function requireAccess(IAccessControl accessControl, address account, uint256 permissionId) internal view {
        requireAccess(accessControl, account, address(this), permissionId);
    }

    function hasAccess(address accessControl, address account, uint256 permissionId) internal view returns (bool) {
        return hasAccess(IAccessControl(accessControl), account, permissionId);
    }

    function hasAccess(IAccessControl accessControl, address account, uint256 permissionId)
        internal
        view
        returns (bool)
    {
        return accessControl.hasAccess({account: account, contractAddress: address(this), permissionId: permissionId});
    }

    function verifyHasAccessFunction(address accessControl) internal view {
        verifyHasAccessFunction(IAccessControl(accessControl));
    }

    function verifyHasAccessFunction(IAccessControl accessControl) internal view {
        accessControl.hasAccess(address(this), address(this), 1); // We expect this to not panic.
    }

    function requireCanChangeAccessControl(address accessControl, address account) internal view {
        requireCanChangeAccessControl(IAccessControl(accessControl), account);
    }

    function requireCanChangeAccessControl(IAccessControl accessControl, address account) internal view {
        require(
            accessControl.canChangeAccessControl({account: account, contractAddress: address(this)}),
            Errors.AccessDenied()
        );
    }
}
