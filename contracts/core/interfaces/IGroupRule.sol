// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";

interface IGroupRule {
    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external payable;

    function processAddition(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external payable;

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external payable;

    function processJoining(
        bytes32 configSalt,
        address account,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external payable;

    function processLeaving(
        bytes32 configSalt,
        address account,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external payable;
}
