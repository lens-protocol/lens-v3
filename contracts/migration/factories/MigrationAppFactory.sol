// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {AppFactory} from "contracts/extensions/factories/AppFactory.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";

contract MigrationAppFactory is AppFactory, EventEmitter {
    constructor(address beacon, address lock) AppFactory(beacon, lock) {}
}
