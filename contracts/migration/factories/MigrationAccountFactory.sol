// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {AccountFactory} from "contracts/extensions/factories/AccountFactory.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";

contract MigrationAccountFactory is AccountFactory, EventEmitter {
    constructor(address beacon, address lock) AccountFactory(beacon, lock) {}
}
