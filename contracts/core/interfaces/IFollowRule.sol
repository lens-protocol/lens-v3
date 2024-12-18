// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue} from "./../types/Types.sol";

interface IFollowRule {
    function configure(address account, bytes32 configSalt, KeyValue[] calldata ruleParams) external;

    function processFollow(
        bytes32 configSalt,
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleExecutionParams
    ) external;
}
