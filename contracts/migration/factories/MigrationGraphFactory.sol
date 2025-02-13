// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {GraphFactory} from "contracts/extensions/factories/GraphFactory.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";

contract MigrationGraphFactory is GraphFactory, EventEmitter {
    constructor(address primitiveBeacon, address proxyAdminLock, address lensFactory)
        GraphFactory(primitiveBeacon, proxyAdminLock, lensFactory)
    {}
}
