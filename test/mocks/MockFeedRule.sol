// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFeedRule} from "contracts/primitives/feed/IFeedRule.sol";
import {CreatePostParams, EditPostParams, CreateRepostParams} from "contracts/primitives/feed/IFeed.sol";
import {RuleConfiguration} from "contracts/types/Types.sol";

contract MockFeedRule {
    bool public shouldRevert;
    bool public shouldReturnFalse;

    function configure(bytes memory configData) external {
        // Configure the rule (e.g., set behavior based on configData)
        // For simplicity, we'll set shouldRevert or shouldReturnFalse
        (shouldRevert, shouldReturnFalse) = abi.decode(configData, (bool, bool));
    }

    function processCreatePost(uint256, uint256, CreatePostParams calldata) external returns (bool) {
        if (shouldRevert) {
            revert("MockFeedRule: Reverted in processCreatePost");
        }
        return !shouldReturnFalse;
    }

    function processCreateRepost(uint256, uint256, CreateRepostParams calldata) external returns (bool) {
        if (shouldRevert) {
            revert("MockFeedRule: Reverted in processCreateRepost");
        }
        return !shouldReturnFalse;
    }

    function processEditPost(uint256, EditPostParams calldata, bytes calldata) external returns (bool) {
        if (shouldRevert) {
            revert("MockFeedRule: Reverted in processEditPost");
        }
        return !shouldReturnFalse;
    }

    function processDeletePost(uint256, bytes calldata) external returns (bool) {
        if (shouldRevert) {
            revert("MockFeedRule: Reverted in processDeletePost");
        }
        return !shouldReturnFalse;
    }

    function processPostRulesChanged(address, uint256, RuleConfiguration[] calldata, bytes calldata)
        external
        returns (bool)
    {
        if (shouldRevert) {
            revert("MockFeedRule: Reverted in processPostRulesChanged");
        }
        return !shouldReturnFalse;
    }
}
