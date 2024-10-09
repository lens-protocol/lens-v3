// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IAccessControl} from "../../primitives/access-control/IAccessControl.sol";

library AccessControlLib {
    function requireAccess(address accessControl, address account, uint256 resourceId) internal view {
        requireAccess(IAccessControl(accessControl), account, resourceId);
    }

    function requireAccess(IAccessControl accessControl, address account, uint256 resourceId) internal view {
        require(accessControl.hasAccess({account: account, resourceLocation: address(this), resourceId: resourceId}));
    }

    function hasAccess(address accessControl, address account, uint256 resourceId) internal view returns (bool) {
        return hasAccess(IAccessControl(accessControl), account, resourceId);
    }

    function hasAccess(IAccessControl accessControl, address account, uint256 resourceId)
        internal
        view
        returns (bool)
    {
        return accessControl.hasAccess({account: account, resourceLocation: address(this), resourceId: resourceId});
    }

    function verifyHasAccessFunction(address accessControl) internal view {
        verifyHasAccessFunction(IAccessControl(accessControl));
    }

    function verifyHasAccessFunction(IAccessControl accessControl) internal view {
        accessControl.hasAccess(address(0), address(0), 0); // We expect this to not panic.
    }
}
