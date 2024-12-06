// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue, RuleChange} from "./../types/Types.sol";

interface IGraphRule {
    function configure(bytes4 ruleSelector, bytes32 salt, KeyValue[] calldata ruleConfigurationParams) external;

    function processFollow(
        bytes32 configSalt,
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] calldata ruleExecutionParams
    ) external returns (bool);

    function processFollowRuleChanges(
        bytes32 configSalt,
        address account,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata ruleExecutionParams
    ) external returns (bool);
}
