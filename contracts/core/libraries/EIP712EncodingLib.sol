// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue, RuleChange, RuleConfigurationChange, RuleSelectorChange} from "contracts/core/types/Types.sol";
import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";

library EIP712EncodingLib {
    function encodeForEIP712(bytes[] memory bytesArray) internal pure returns (bytes32) {
        bytes32[] memory bytesArrayEncodedElements = new bytes32[](bytesArray.length);
        uint256 i;
        while (i < bytesArray.length) {
            // A `bytes` type is encoded as its keccak256 hash.
            bytesArrayEncodedElements[i] = encodeForEIP712(bytesArray[i]);
            unchecked {
                ++i;
            }
        }
        // An array is encoded as the keccak256 hash of the concatenation of their encoded elements.
        return encodeForEIP712(bytesArrayEncodedElements);
    }

    function encodeForEIP712(bool[] memory boolArray) internal pure returns (bytes32) {
        return keccak256(abi.encode(boolArray));
    }

    function encodeForEIP712(address[] memory addressArray) internal pure returns (bytes32) {
        return keccak256(abi.encode(addressArray));
    }

    function encodeForEIP712(uint256[] memory uint256Array) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256Array));
    }

    function encodeForEIP712(bytes32[] memory bytes32Array) internal pure returns (bytes32) {
        return keccak256(abi.encode(bytes32Array));
    }

    function encodeForEIP712(KeyValue[] memory keyValueArray) internal pure returns (bytes32) {
        bytes32[] memory keyValueEncodedElements = new bytes32[](keyValueArray.length);
        for (uint256 i = 0; i < keyValueArray.length; i++) {
            keyValueEncodedElements[i] = encodeForEIP712(keyValueArray[i]);
        }
        return encodeForEIP712(keyValueEncodedElements);
    }

    function encodeForEIP712(RuleChange[] memory ruleChangeArray) internal pure returns (bytes32) {
        bytes32[] memory ruleChangeEncodedElements = new bytes32[](ruleChangeArray.length);
        for (uint256 i = 0; i < ruleChangeArray.length; i++) {
            ruleChangeEncodedElements[i] = encodeForEIP712(ruleChangeArray[i]);
        }
        return encodeForEIP712(ruleChangeEncodedElements);
    }

    function encodeForEIP712(RuleSelectorChange[] memory ruleSelectorChangeArray) internal pure returns (bytes32) {
        bytes32[] memory ruleSelectorChangeEncodedElements = new bytes32[](ruleSelectorChangeArray.length);
        for (uint256 i = 0; i < ruleSelectorChangeArray.length; i++) {
            ruleSelectorChangeEncodedElements[i] = encodeForEIP712(ruleSelectorChangeArray[i]);
        }
        return encodeForEIP712(ruleSelectorChangeEncodedElements);
    }

    function encodeForEIP712(KeyValue memory keyValue) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("KeyValue(bytes32 key,bytes value)"), // Type Hash
                keyValue.key,
                encodeForEIP712(keyValue.value)
            )
        );
    }

    function encodeForEIP712(RuleChange memory ruleChange) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "RuleChange(address ruleAddress,bytes32 configSalt,RuleConfigurationChange configurationChanges,RuleSelectorChange[] selectorChanges)KeyValue(bytes32 key,bytes value)RuleConfigurationChange(bool configure,KeyValue[] ruleParams)RuleSelectorChange(bytes4 ruleSelector,bool isRequired,bool enabled)"
                ), // Type Hash
                ruleChange.ruleAddress,
                ruleChange.configSalt,
                encodeForEIP712(ruleChange.configurationChanges),
                encodeForEIP712(ruleChange.selectorChanges)
            )
        );
    }

    function encodeForEIP712(RuleConfigurationChange memory ruleConfigurationChange) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "RuleConfigurationChange(bool configure,KeyValue[] ruleParams)KeyValue(bytes32 key,bytes value)"
                ), // Type Hash
                ruleConfigurationChange.configure,
                encodeForEIP712(ruleConfigurationChange.ruleParams)
            )
        );
    }

    function encodeForEIP712(RuleSelectorChange memory ruleSelectorChange) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("RuleSelectorChange(bytes4 ruleSelector,bool isRequired,bool enabled)"), // Type Hash
                ruleSelectorChange.ruleSelector,
                ruleSelectorChange.isRequired,
                ruleSelectorChange.enabled
            )
        );
    }

    function encodeForEIP712(CreatePostParams memory createPostParams) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "CreatePostParams(address author,string contentURI,uint256 repostedPostId,uint256 quotedPostId,uint256 repliedPostId,RuleChange[] ruleChanges,KeyValue[] extraData)KeyValue(bytes32 key,bytes value)RuleChange(address ruleAddress,bytes32 configSalt,RuleConfigurationChange configurationChanges,RuleSelectorChange[] selectorChanges)RuleConfigurationChange(bool configure,KeyValue[] ruleParams)RuleSelectorChange(bytes4 ruleSelector,bool isRequired,bool enabled)"
                ), // Type Hash
                createPostParams.author,
                encodeForEIP712(createPostParams.contentURI),
                createPostParams.repostedPostId,
                createPostParams.quotedPostId,
                createPostParams.repliedPostId,
                encodeForEIP712(createPostParams.ruleChanges),
                encodeForEIP712(createPostParams.extraData)
            )
        );
    }

    function encodeForEIP712(EditPostParams memory editPostParams) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EditPostParams(string contentURI,KeyValue[] extraData)KeyValue(bytes32 key,bytes value)"), // Type Hash
                encodeForEIP712(editPostParams.contentURI),
                encodeForEIP712(editPostParams.extraData)
            )
        );
    }

    function encodeForEIP712(string memory stringValue) internal pure returns (bytes32) {
        return keccak256(bytes(stringValue));
    }

    function encodeForEIP712(bytes memory bytesValue) internal pure returns (bytes32) {
        return keccak256(bytesValue);
    }
}
