// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPostRule} from "contracts/primitives/feed/IPostRule.sol";
import {RuleConfiguration} from "contracts/types/Types.sol";

contract MockPostRule {
    bool public shouldRevert;
    bool public shouldReturnFalse;

    function configure(uint256, bytes memory configData) external {
        // Configure the rule
        (shouldRevert, shouldReturnFalse) = abi.decode(configData, (bool, bool));
    }

    function processParent(uint256, uint256, bytes calldata) external returns (bool) {
        if (shouldRevert) {
            revert("MockPostRule: Reverted in processParent");
        }
        return !shouldReturnFalse;
    }

    function processQuote(uint256, uint256, bytes calldata) external returns (bool) {
        if (shouldRevert) {
            revert("MockPostRule: Reverted in processQuote");
        }
        return !shouldReturnFalse;
    }

    function processChildPostRulesChanged(uint256, uint256, RuleConfiguration[] calldata, bytes calldata)
        external
        returns (bool)
    {
        if (shouldRevert) {
            revert("MockPostRule: Reverted in processChildPostRulesChanged");
        }
        return !shouldReturnFalse;
    }
}
