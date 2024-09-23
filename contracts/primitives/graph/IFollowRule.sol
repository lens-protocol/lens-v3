// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRule} from "./../rules/IRule.sol";
import {RuleConfiguration} from "./../../types/Types.sol";

interface IFollowRule {
    // This should be called by the primitive, and stored under the "msg.sender" context (msg.sender == primitive)
    function _configure(address account, RuleConfiguration calldata ruleConfiguration) internal;

    /**
     * Predicate to be evaluated upon each follow using the logic set by `accountToFollow`. Finishes execution
     * successfully if the predicate evalues to "true", reverts if the predicate evaluates to "false".
     * @param accountToFollow The account to be followed.
     * @param data Data that the rule might require to evalute the follow.
     */
    function _processFollow(address msgSender, address accountToFollow, uint256 followId, bytes calldata data)
        external;

    // We don't have processUnfollow() function because it can prevent from unfollowing or have other weird consequences

    // TODO: We can add a standard function here like `processAfterUnfollow` or some more clear name
    // That should be called by the user after the unfollow, to clean state or withdraw stuff.
    // The idea of adding it in the interface is to standarize it, so everyone can call it without making it bespoke to
    // each module.
}
