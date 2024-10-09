// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICommunityRule} from "./ICommunityRule.sol";
import {RulesStorage, RulesLib} from "./../base/RulesLib.sol";
import {RuleConfiguration, RuleExecutionData} from "./../../types/Types.sol";

contract RuleBasedCommunity {
    using RulesLib for RulesStorage;

    struct RuleBasedStorage {
        RulesStorage communityRulesStorage;
    }

    // keccak256('lens.rule.based.community.storage')
    bytes32 constant RULE_BASED_COMMUNITY_STORAGE_SLOT =
        0x6b4f86fd68b78c2e5c3c4bc3b3dbb99669a3da3f0bb2db367c4d64acdb2fd3d9;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := RULE_BASED_COMMUNITY_STORAGE_SLOT
        }
    }

    function $communityRulesStorage() private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().communityRulesStorage;
    }

    // Internal

    function _addCommunityRule(RuleConfiguration calldata rule) internal {
        $communityRulesStorage().addRule(
            rule, abi.encodeWithSelector(ICommunityRule.configure.selector, rule.configData)
        );
    }

    function _updateCommunityRule(RuleConfiguration calldata rule) internal {
        $communityRulesStorage().updateRule(
            rule, abi.encodeWithSelector(ICommunityRule.configure.selector, rule.configData)
        );
    }

    function _removeCommunityRule(address rule) internal {
        $communityRulesStorage().removeRule(rule);
    }

    function _processJoining(address account, uint256 membershipId, RuleExecutionData calldata data) internal {
        _processCommunityRule(ICommunityRule.processJoining.selector, account, membershipId, data);
    }

    function _processRemoval(address account, uint256 membershipId, RuleExecutionData calldata data) internal {
        _processCommunityRule(ICommunityRule.processRemoval.selector, account, membershipId, data);
    }

    function _processLeaving(address account, uint256 membershipId, RuleExecutionData calldata data) internal {
        _processCommunityRule(ICommunityRule.processLeaving.selector, account, membershipId, data);
    }

    function _processCommunityRule(
        bytes4 selector,
        address account,
        uint256 membershipId,
        RuleExecutionData calldata data
    ) private {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $communityRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $communityRulesStorage().requiredRules[i].call(
                abi.encodeWithSelector(selector, account, membershipId, data.dataForRequiredRules[i])
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($communityRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $communityRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $communityRulesStorage().anyOfRules[i].call(
                abi.encodeWithSelector(selector, account, membershipId, data.dataForAnyOfRules[i])
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the any-of rules failed");
    }

    function _getCommunityRules(bool isRequired) internal view returns (address[] memory) {
        return $communityRulesStorage().getRulesArray(isRequired);
    }
}
