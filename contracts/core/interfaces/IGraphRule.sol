// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue, RuleChange} from "contracts/core/types/Types.sol";

interface IGraphRule {
    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external;

    function processFollow(
        bytes32 configSalt,
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;

    function processUnfollow(
        bytes32 configSalt,
        address originalMsgSender,
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external;

    function processFollowRuleChanges(
        bytes32 configSalt,
        address account,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata ruleParams
    ) external;
}
