// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

struct KeyValue {
    bytes32 key;
    bytes value;
}

struct Rule {
    address ruleAddress;
    bytes32 configSalt;
}

struct RuleChange {
    address ruleAddress;
    bytes32 configSalt;
    RuleConfigurationChange configurationChanges;
    RuleSelectorChange[] selectorChanges;
}

struct RuleConfigurationChange {
    bool configure;
    KeyValue[] ruleParams;
}

struct RuleSelectorChange {
    bytes4 ruleSelector;
    bool isRequired;
    bool enabled;
}

struct RuleProcessingParams {
    address ruleAddress;
    bytes32 configSalt;
    KeyValue[] ruleParams;
}

struct SourceStamp {
    address source;
    address originalMsgSender; // Who called the validator to execute some action with a source (e.g. Account)
    address validator; // Who is calling the source to validate the source stamp (e.g. Lens Primitives)
    uint256 nonce;
    uint256 deadline;
    bytes signature;
}
