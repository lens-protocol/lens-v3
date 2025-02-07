// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";

interface IGroupRule {
    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external;

    /**
     * The `processAddition` logic should be written so that it can serve as a SUFFICIENT condition when it is
     * the only rule applied. In other words, it should be capable of safely handling the entire membership
     * addition flow on its own.
     *
     * If, however, `processAddition` only addresses part of the required member addition logic (i.e. it is NECESSARY
     * BUT NOT SUFFICIENT), you may encounter unexpected behavior when it is not combined with any complementary rules.
     */
    function processAddition(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;

    /**
     * The `processRemoval` logic should be written so that it can serve as a SUFFICIENT condition when it is
     * the only rule applied. In other words, it should be capable of safely handling the entire membership
     * removal flow on its own.
     *
     * If, however, `processRemoval` only addresses part of the required member removal logic (i.e. it is NECESSARY
     * BUT NOT SUFFICIENT), you may encounter unexpected behavior when it is not combined with any complementary rules.
     */
    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;

    function processJoining(
        bytes32 configSalt,
        address account,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;

    function processLeaving(
        bytes32 configSalt,
        address account,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;
}
