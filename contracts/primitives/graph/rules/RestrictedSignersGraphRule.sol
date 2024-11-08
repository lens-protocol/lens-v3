// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGraphRule} from "../IGraphRule.sol";
import {RestrictedSignersRule, EIP712Signature} from "../../base/RestrictedSignersRule.sol";
import {RuleConfiguration} from "../../../types/Types.sol";

contract RestrictedSignersGraphRule is RestrictedSignersRule, IGraphRule {
    function configure(bytes calldata data) external override {
        _configure(data);
    }

    function processFollow(address followerAccount, address accountToFollow, uint256 followId, bytes calldata data)
        external
        override
        returns (bool)
    {
        _validateRestrictedSignerMessage({
            functionSelector: IGraphRule.processFollow.selector,
            abiEncodedFunctionParams: abi.encode(followerAccount, accountToFollow, followId),
            signature: abi.decode(data, (EIP712Signature))
        });
        return true;
    }

    function processUnfollow(
        address unfollowerAccount,
        address accountToUnfollow,
        uint256 followId,
        bytes calldata data
    ) external override returns (bool) {
        _validateRestrictedSignerMessage({
            functionSelector: IGraphRule.processUnfollow.selector,
            abiEncodedFunctionParams: abi.encode(unfollowerAccount, accountToUnfollow, followId),
            signature: abi.decode(data, (EIP712Signature))
        });
        return true;
    }

    function processFollowRulesChange(address account, RuleConfiguration[] calldata followRules, bytes calldata data)
        external
        override
        returns (bool)
    {
        _validateRestrictedSignerMessage({
            functionSelector: IGraphRule.processFollowRulesChange.selector,
            abiEncodedFunctionParams: abi.encode(account, followRules),
            signature: abi.decode(data, (EIP712Signature))
        });
        return true;
    }
}
