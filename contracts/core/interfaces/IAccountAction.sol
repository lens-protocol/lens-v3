// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue} from "./../types/Types.sol";

interface IAccountAction {
    event Lens_AccountAction_Configured(address indexed account, KeyValue[] params);

    event Lens_AccountAction_Executed(address indexed account, KeyValue[] params);

    function configure(address account, KeyValue[] calldata params) external returns (bytes memory);

    function execute(address account, KeyValue[] calldata params) external returns (bytes memory);
}
