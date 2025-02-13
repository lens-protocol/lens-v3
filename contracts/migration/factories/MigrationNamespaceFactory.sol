// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {NamespaceFactory} from "contracts/extensions/factories/NamespaceFactory.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";

contract MigrationNamespaceFactory is NamespaceFactory, EventEmitter {
    constructor(address primitiveBeacon, address proxyAdminLock, address lensFactory)
        NamespaceFactory(primitiveBeacon, proxyAdminLock, lensFactory)
    {}
}
