// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue} from "./../types/Types.sol";

interface IUsernameRule {
    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external;

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string calldata username,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        string calldata username,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;

    function processAssigning(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string calldata username,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;

    function processUnassigning(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string calldata username,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;
}
