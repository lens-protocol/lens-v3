// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFollowRule} from "./IFollowRule.sol";

import {IRule} from "./../rules/IRule.sol";

interface IGraphRule is IRule {
    function processFollow(
        address originalMsgSender,
        address followerAcount,
        address accountToFollow,
        uint256 followId,
        bytes calldata data
    ) internal;

    // TODO: Should this exist? Maybe not, so it cannot prevent the unfollow...
    // Maybe the function should exist but not being called by `unfollow` but by the user in a separate tx later.
    // We could even do wrappers for this, given that all the accounts are smart contracts
    function processUnfollow(
        address originalMsgSender,
        address followerAccount,
        address accountToUnfollow,
        uint256 followId,
        bytes calldata data
    ) internal;

    // TODO: Should the block be global? Or at least have a global registry to signal it too...
    function processBlock(address account, bytes calldata data) external;

    function processUnblock(address account, bytes calldata data) external;

    function processFollowRulesChange(address account, address[] followRules, bytes calldata data) external;
}

interface IRule {
    function configure(bytes calldata primitiveParams, bytes calldata userParams) external virtual;

    function process(bytes4 selector, bytes calldata primitiveParams, bytes calldata userParams) external virtual;

    function processFollowRulesChange(address account, address[] memory followRules, bytes calldata data)
        internal
        virtual
        returns (bool)
    {
        return false;
    }
}

contract GraphRuleBase is IRule {
    function process(bytes4 selector, bytes memory primitiveParams, bytes memory userParams)
        external
        virtual
        override
        returns (bool)
    {
        if (selector == IGraphRule.processFollowRulesChange.selector) {
            (address account, address[] memory followRules) = abi.decode(primitiveParams, (address, address[]));
            processFollowRulesChange(account, followRules, userParams);
        } else if (selector == IGraphRule.processFollow.selector) {
            (address originalMsgSender, address followerAcount, address accountToFollow, uint256 followId) =
                abi.decode(primitiveParams, (address, address, address, uint256));
            processFollow(originalMsgSender, followerAcount, accountToFollow, followId, userParams);
        } else if (selector == IGraphRule.processUnfollow.selector) {
            (address originalMsgSender, address followerAccount, address accountToUnfollow, uint256 followId) =
                abi.decode(primitiveParams, (address, address, address, uint256));
            processUnfollow(originalMsgSender, followerAccount, accountToUnfollow, followId, userParams);
        } else if (selector == IGraphRule.processBlock.selector) {
            (address account) = abi.decode(primitiveParams, (address));
            processBlock(account, userParams);
        } else if (selector == IGraphRule.processUnblock.selector) {
            (address account) = abi.decode(primitiveParams, (address));
            processUnblock(account, userParams);
        } else {
            return false;
        }
    }
}

contract GraphRule is GraphRuleBase {
    function processFollowRulesChange(address account, address[] memory followRules, bytes calldata data)
        internal
        override
    {
        // Developer rule code goes here
    }
}

contract PayToDoSomethingRule is IRule {
    function process(bytes4 selector, bytes memory primitiveParams, bytes memory userParams)
        external
        virtual
        override
        returns (bool)
    {
        _processPayment(primitiveParams, userParams);
    }
}
