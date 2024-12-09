// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue} from "./../types/Types.sol";

interface IGroupRule {
    function configure(bytes4 ruleSelector, bytes32 salt, KeyValue[] calldata ruleConfigurationParams) external;

    function processAddition(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleExecutionParams
    ) external returns (bool);

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleExecutionParams
    ) external returns (bool);

    function processJoining(
        bytes32 configSalt,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleExecutionParams
    ) external returns (bool);

    function processLeaving(
        bytes32 configSalt,
        address account,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleExecutionParams
    ) external returns (bool);
}
