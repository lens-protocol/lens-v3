// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract UsernameSimpleCharsetNamespaceRule is INamespaceRule, MetadataBased {
    event Lens_Rule_MetadataURISet(string metadataURI);

    constructor(string memory metadataURI) {
        _setMetadataURI(metadataURI);
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Rule_MetadataURISet(metadataURI);
    }

    function configure(bytes32, /* configSalt */ KeyValue[] calldata /* ruleParams */ ) external override {}

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
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
