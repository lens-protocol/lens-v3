// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGraphRule} from "./../../core/interfaces/IGraphRule.sol";
import {RestrictedSignersRule, EIP712Signature} from "./../base/RestrictedSignersRule.sol";
import {RuleChange} from "./../../core/types/Types.sol";

contract RestrictedSignersGraphRule is RestrictedSignersRule, IGraphRule {
    function configure(bytes calldata data) external override {
        _configure(data);
    }

    function processFollow(
        address followerAccount,
        address accountToFollow,
        bytes calldata data
    ) external override returns (bool) {
        _validateRestrictedSignerMessage({
            functionSelector: IGraphRule.processFollow.selector,
            abiEncodedFunctionParams: abi.encode(followerAccount, accountToFollow),
            signature: abi.decode(data, (EIP712Signature))
        });
        return true;
    }

    function processFollowRuleChanges(
        address account,
        RuleChange[] calldata ruleChanges,
        bytes calldata data
    ) external override returns (bool) {
        _validateRestrictedSignerMessage({
            functionSelector: IGraphRule.processFollowRuleChanges.selector,
            abiEncodedFunctionParams: abi.encode(account, ruleChanges),
            signature: abi.decode(data, (EIP712Signature))
        });
        return true;
    }
}
