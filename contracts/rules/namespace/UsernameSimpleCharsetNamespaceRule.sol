// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract UsernameSimpleCharsetNamespaceRule is OwnableMetadataBasedRule, Initializable, INamespaceRule {
    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32, /* configSalt */ KeyValue[] calldata /* ruleParams */ ) external override {}

    function processCreation(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        _processRestrictions(username);
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processAssigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processUnassigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function _processRestrictions(string calldata username) internal pure {
        // Can only start with a-z or 0-9 (not with a dash or underscore)
        require(_isLatinLowercase(bytes(username)[0]) || _isNumeric(bytes(username)[0]), Errors.CannotStartWithThat());
        // The rest of the username can also have underscore and dash
        for (uint256 i = 1; i < bytes(username).length; i++) {
            bytes1 char = bytes(username)[i];
            require(_isLatinLowercase(char) || _isNumeric(char) || char == "_" || char == "-", Errors.NotAllowed());
        }
    }

    // Internal Charset Helper functions

    /// @dev We only accept lowercase characters to avoid confusion.
    /// @param char The character to check.
    /// @return True if the character is alphanumeric, false otherwise.
    function _isNumeric(bytes1 char) internal pure returns (bool) {
        return (char >= "0" && char <= "9");
    }

    /// @dev We only accept lowercase characters to avoid confusion.
    /// @param char The character to check.
    /// @return True if the character is alphanumeric, false otherwise.
    function _isLatinLowercase(bytes1 char) internal pure returns (bool) {
        return (char >= "a" && char <= "z");
    }
}
