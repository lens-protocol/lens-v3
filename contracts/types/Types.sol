// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct DataElement {
    bytes32 key;
    bytes value;
}

struct RuleConfiguration {
    address ruleAddress;
    bytes configData;
    bool isRequired;
}

struct RuleExecutionData {
    bytes[] dataForRequiredRules;
    bytes[] dataForAnyOfRules;
}
