// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Account} from "contracts/extensions/account/Account.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";

contract MigrationAccount is Account, EventEmitter {}
