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

struct RuleProcessingParams {
    address ruleAddress;
    bytes32 configSalt;
    KeyValue[] customParams;
}

struct RuleChange {
    RuleConfigurationParams configuration;
    RuleOperation operation;
}

struct RuleConfigurationParams {
    bytes4 ruleSelector;
    address ruleAddress;
    bool isRequired;
    bytes32 configSalt;
    KeyValue[] customParams;
}

enum RuleOperation {
    ADD,
    UPDATE,
    REMOVE
}

struct SourceStamp {
    address source;
    uint256 nonce;
    uint256 deadline;
    bytes signature;
}
