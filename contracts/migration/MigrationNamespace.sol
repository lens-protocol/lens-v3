// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Namespace} from "contracts/core/primitives/namespace/Namespace.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";

contract MigrationNamespace is Namespace, EventEmitter {}
