// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {KeyValue} from "contracts/core/types/Types.sol";

interface IRequestBasedGroupRule is IGroupRule {
    function sendMembershipRequest(bytes32 configSalt, address group, KeyValue[] calldata params) external;

    function cancelMembershipRequest(bytes32 configSalt, address group, KeyValue[] calldata params) external;
}
