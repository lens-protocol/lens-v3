// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RuleConfiguration} from "./../../types/Types.sol";

interface IFollowRule {
    function configure(address account, bytes calldata data) external;

    function processFollow(address followerAccount, address accountToFollow, uint256 followId, bytes calldata data)
        external;

    // We don't have processUnfollow() function because it can prevent from unfollowing or have other weird consequences
    // function processUnfollow(address followerAccount, address accountToUnfollow, uint256 followId, bytes calldata data)
    //     external;

    // TODO: We can add a standard function here like `processAfterUnfollow` or some more clear name
    // That should be called by the user after the unfollow, to clean state or withdraw stuff.
    // The idea of adding it in the interface is to standarize it, so everyone can call it without making it bespoke to
    // each module.
}
