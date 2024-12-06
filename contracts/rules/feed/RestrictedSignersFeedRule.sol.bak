// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {CreatePostParams, EditPostParams} from "./../../core/interfaces/IFeed.sol";
import {IFeedRule} from "./../../core/interfaces/IFeedRule.sol";
import {RestrictedSignersRule, EIP712Signature} from "./../base/RestrictedSignersRule.sol";
import {RuleChange} from "./../../core/types/Types.sol";

contract RestrictedSignersFeedRule is RestrictedSignersRule, IFeedRule {
    function configure(bytes calldata data) external override {
        _configure(data);
    }

    function processCreatePost(
        uint256 postId,
        CreatePostParams calldata postParams,
        bytes calldata data
    ) external override returns (bool) {
        _validateRestrictedSignerMessage({
            functionSelector: IFeedRule.processCreatePost.selector,
            abiEncodedFunctionParams: abi.encode(postId, postParams),
            signature: abi.decode(data, (EIP712Signature))
        });
        return true;
    }

    function processEditPost(
        uint256 postId,
        EditPostParams calldata editPostParams,
        bytes calldata data
    ) external override returns (bool) {
        _validateRestrictedSignerMessage({
            functionSelector: IFeedRule.processEditPost.selector,
            abiEncodedFunctionParams: abi.encode(postId, editPostParams),
            signature: abi.decode(data, (EIP712Signature))
        });
        return true;
    }

    function processPostRuleChanges(
        uint256 postId,
        RuleChange[] calldata ruleChanges,
        bytes calldata data
    ) external override returns (bool) {
        _validateRestrictedSignerMessage({
            functionSelector: IFeedRule.processPostRuleChanges.selector,
            abiEncodedFunctionParams: abi.encode(postId, ruleChanges),
            signature: abi.decode(data, (EIP712Signature))
        });
        return true;
    }
}
