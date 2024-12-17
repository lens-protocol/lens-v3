// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

struct KeyValue {
    bytes32 key;
    bytes value;
}

struct Rule {
    address addr;
    bytes32 configSalt;
}

struct RuleConfigurationChange {
    address ruleAddress;
    bytes32 configSalt;
    KeyValue[] ruleParams;
}

struct RuleSelectorChange {
    address ruleAddress;
    bytes32 configSalt;
    bool isRequired;
    bytes4[] ruleSelectors;
    bool enabled;
}

struct RuleProcessingParams {
    address ruleAddress;
    bytes32 configSalt;
    KeyValue[] ruleParams;
}

struct SourceStamp {
    address source;
    uint256 nonce;
    uint256 deadline;
    bytes signature;
}
