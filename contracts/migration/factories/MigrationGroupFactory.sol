// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {GroupFactory} from "contracts/extensions/factories/GroupFactory.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";

contract MigrationGroupFactory is GroupFactory, EventEmitter {
    constructor(address primitiveBeacon, address proxyAdminLock) GroupFactory(primitiveBeacon, proxyAdminLock) {}
}
