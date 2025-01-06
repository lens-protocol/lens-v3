// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {PermissionlessAccessControl} from "contracts/extensions/access/PermissionlessAccessControl.sol";

contract PrimitiveFactory {
    IAccessControl internal immutable TEMPORARY_ACCESS_CONTROL;
    address internal immutable PRIMITIVE_BEACON;
    address internal immutable PROXY_ADMIN_LOCK;

    constructor(address primitiveBeacon, address proxyAdminLock) {
        TEMPORARY_ACCESS_CONTROL = new PermissionlessAccessControl();
        PRIMITIVE_BEACON = primitiveBeacon;
        PROXY_ADMIN_LOCK = proxyAdminLock;
    }
}
