// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RuleConfiguration} from "./../../types/Types.sol";

interface IGraphRule {
    function configure(bytes calldata data) external;

    function processFollow(address followerAcount, address accountToFollow, uint256 followId, bytes calldata data)
        external;

    // TODO: Should this exist? Maybe not, so it cannot prevent the unfollow...
    // Maybe the function should exist but not being called by `unfollow` but by the user in a separate tx later.
    // We could even do wrappers for this, given that all the accounts are smart contracts
    function processUnfollow(
        address unfollowerAccount,
        address accountToUnfollow,
        uint256 followId,
        bytes calldata data
    ) external;

    // TODO: We will try to implement this using a registry
    // function processBlock(address account, bytes calldata data) external;

    // function processUnblock(address account, bytes calldata data) external;

    function processFollowRulesChange(address account, RuleConfiguration[] calldata followRules, bytes calldata data)
        external;
}
