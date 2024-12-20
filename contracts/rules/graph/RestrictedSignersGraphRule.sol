// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGraphRule} from "./../../core/interfaces/IGraphRule.sol";
import {RestrictedSignersRule, EIP712Signature} from "./../base/RestrictedSignersRule.sol";
import {KeyValue, RuleChange} from "./../../core/types/Types.sol";
import {EIP712EncodingLib} from "./../../core/libraries/EIP712EncodingLib.sol";

contract RestrictedSignersGraphRule is RestrictedSignersRule, IGraphRule {
    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        _configure(configSalt, ruleParams);
    }

    function processFollow(
        bytes32 configSalt,
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external override {
        _validateRestrictedSignerMessage({
            configSalt: configSalt,
            functionSelector: IGraphRule.processFollow.selector,
            abiEncodedFunctionParams: abi.encode(
                originalMsgSender, followerAccount, accountToFollow, EIP712EncodingLib.encodeForEIP712(primitiveParams)
            ),
            signature: abi.decode(ruleParams[0].value, (EIP712Signature))
        });
    }

    function processUnfollow(
        bytes32 configSalt,
        address originalMsgSender,
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata primitiveParams,
        KeyValue[] calldata ruleParams
    ) external override {
        _validateRestrictedSignerMessage({
            configSalt: configSalt,
            functionSelector: IGraphRule.processUnfollow.selector,
            abiEncodedFunctionParams: abi.encode(
                originalMsgSender, followerAccount, accountToUnfollow, EIP712EncodingLib.encodeForEIP712(primitiveParams)
            ),
            signature: abi.decode(ruleParams[0].value, (EIP712Signature))
        });
    }

    function processFollowRuleChanges(
        bytes32 configSalt,
        address account,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata ruleParams
    ) external override {
        _validateRestrictedSignerMessage({
            configSalt: configSalt,
            functionSelector: IGraphRule.processFollowRuleChanges.selector,
            abiEncodedFunctionParams: abi.encode(account, EIP712EncodingLib.encodeForEIP712(ruleChanges)),
            signature: abi.decode(ruleParams[0].value, (EIP712Signature))
        });
    }
}
