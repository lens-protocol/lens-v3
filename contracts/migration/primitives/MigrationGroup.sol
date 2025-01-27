// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Group} from "contracts/core/primitives/group/Group.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";

contract MigrationGroup is Group, EventEmitter {}
