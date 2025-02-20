// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {App} from "contracts/extensions/primitives/app/App.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";

contract MigrationApp is App, EventEmitter {}
