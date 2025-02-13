// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {FeedFactory} from "contracts/extensions/factories/FeedFactory.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";

contract MigrationFeedFactory is FeedFactory, EventEmitter {
    constructor(address primitiveBeacon, address proxyAdminLock, address lensFactory)
        FeedFactory(primitiveBeacon, proxyAdminLock, lensFactory)
    {}
}
