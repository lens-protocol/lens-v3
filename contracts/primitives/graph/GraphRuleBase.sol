// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGraphRule} from "./IGraphRule.sol";

abstract contract GraphRuleBase is IGraphRule {
    function configure(bytes4 selector, bytes memory primitiveParams, bytes memory userParams)
        external
        virtual
        override
    {
        _configure(primitiveParams, userParams);
        emit Lens_RuleConfigured(address(this), selector, primitiveParams, userParams);
    }

    function process(bytes4 selector, bytes memory primitiveParams, bytes memory userParams)
        external
        virtual
        override
        returns (bool)
    {
        // TODO: Think how to replace this string keccak with an Interface.selector so we have access from the primitive
        if (selector == FOLLOW_SELECTOR) {
            (address originalMsgSender, address followerAcount, address targetAccountToFollow, uint256 followId) =
                abi.decode(primitiveParams, (address, address, address, uint256));
            return _processFollow(originalMsgSender, followerAcount, targetAccountToFollow, followId, userParams);
        } else if (selector == UNFOLLOW_SELECTOR) {
            (address originalMsgSender, address followerAccount, address targetAccountToUnfollow, uint256 followId) =
                abi.decode(primitiveParams, (address, address, address, uint256));
            return _processUnfollow(originalMsgSender, followerAccount, targetAccountToUnfollow, followId, userParams);
        } else if (selector == BLOCK_SELECTOR) {
            (address account) = abi.decode(primitiveParams, (address));
            return _processBlock(account, userParams);
        } else if (selector == UNBLOCK_SELECTOR) {
            (address account) = abi.decode(primitiveParams, (address));
            return _processUnblock(account, userParams);
        } else if (selector == FOLLOW_RULES_CHANGE_SELECTOR) {
            (address account, address[] memory followRules) = abi.decode(primitiveParams, (address, address[]));
            return _processFollowRulesChange(account, followRules, userParams);
        } else {
            return false;
        }
    }

    function _configure(bytes memory primitiveParams, bytes calldata userParams) internal virtual;

    function _processFollow(
        address originalMsgSender,
        address followerAcount,
        address targetAccountToFollow,
        uint256 followId,
        bytes calldata data
    ) internal virtual returns (bool isImplemented);

    // TODO: Should this exist? Maybe not, so it cannot prevent the unfollow...
    // Maybe the function should exist but not being called by `unfollow` but by the user in a separate tx later.
    // We could even do wrappers for this, given that all the accounts are smart contracts
    function _processUnfollow(
        address originalMsgSender,
        address followerAccount,
        address targetAccountToUnfollow,
        uint256 followId,
        bytes calldata data
    ) internal virtual returns (bool isImplemented);

    // TODO: Should the block be global? Or at least have a global registry to signal it too...
    function _processBlock(address account, bytes calldata data) internal virtual returns (bool isImplemented);

    function _processUnblock(address account, bytes calldata data) internal virtual returns (bool isImplemented);

    function _processFollowRulesChange(address account, address[] calldata followRules, bytes calldata data)
        internal
        virtual
        returns (bool isImplemented);
}
