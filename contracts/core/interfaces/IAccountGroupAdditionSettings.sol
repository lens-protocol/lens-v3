// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";

interface IAccountGroupAdditionSettings {
    function canBeAddedToGroup(address group, address addedBy, KeyValue[] calldata params)
        external
        view
        returns (bool);
}
