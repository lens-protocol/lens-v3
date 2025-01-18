// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";
import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";
import {RestrictedSignersRule, EIP712Signature} from "contracts/rules/base/RestrictedSignersRule.sol";
import {KeyValue, RuleChange} from "contracts/core/types/Types.sol";
import {EIP712EncodingLib} from "contracts/core/libraries/EIP712EncodingLib.sol";

contract RestrictedSignersFeedRule is RestrictedSignersRule, IFeedRule {
    constructor(string memory metadataURI) RestrictedSignersRule(metadataURI) {}

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        _configure(configSalt, ruleParams);
    }

    function processCreatePost(
        bytes32 configSalt,
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external override {
        _validateRestrictedSignerMessage({
            configSalt: configSalt,
            functionSelector: IFeedRule.processCreatePost.selector,
            abiEncodedFunctionParams: abi.encode(
                postId, EIP712EncodingLib.encodeForEIP712(postParams), EIP712EncodingLib.encodeForEIP712(primitiveParams)
            ),
            signature: abi.decode(ruleParams[0].value, (EIP712Signature))
        });
    }

    function processEditPost(
        bytes32 configSalt,
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external override {
        _validateRestrictedSignerMessage({
            configSalt: configSalt,
            functionSelector: IFeedRule.processEditPost.selector,
            abiEncodedFunctionParams: abi.encode(
                postId, EIP712EncodingLib.encodeForEIP712(postParams), EIP712EncodingLib.encodeForEIP712(primitiveParams)
            ),
            signature: abi.decode(ruleParams[0].value, (EIP712Signature))
        });
    }

    function processDeletePost(
        bytes32 configSalt,
        uint256 postId,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external override {
        _validateRestrictedSignerMessage({
            configSalt: configSalt,
            functionSelector: IFeedRule.processDeletePost.selector,
            abiEncodedFunctionParams: abi.encode(postId, EIP712EncodingLib.encodeForEIP712(primitiveParams)),
            signature: abi.decode(ruleParams[0].value, (EIP712Signature))
        });
    }

    function processPostRuleChanges(
        bytes32 configSalt,
        uint256 postId,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata ruleParams
    ) external override {
        _validateRestrictedSignerMessage({
            configSalt: configSalt,
            functionSelector: IFeedRule.processPostRuleChanges.selector,
            abiEncodedFunctionParams: abi.encode(postId, EIP712EncodingLib.encodeForEIP712(ruleChanges)),
            signature: abi.decode(ruleParams[0].value, (EIP712Signature))
        });
    }
}
