// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFollowRule} from "./IFollowRule.sol";
import {IGraphRule} from "./IGraphRule.sol";
import {RulesStorage, RulesLib} from "./../base/RulesLib.sol";
import {RuleConfiguration, RuleExecutionData} from "./../../types/Types.sol";

contract RuleBasedGraph {
    using RulesLib for RulesStorage;

    struct RuleBasedStorage {
        RulesStorage graphRulesStorage;
        mapping(address => RulesStorage) followRulesStorage;
    }

    // keccak256('lens.rule.based.graph.storage')
    bytes32 constant RULE_BASED_GRAPH_STORAGE_SLOT = 0x02d31ef96f666bf684ab1c8a89d21f38a88719152ba49251cdaacb4c11cdae39;

    function $ruleBasedStorage() private pure returns (RuleBasedStorage storage _storage) {
        assembly {
            _storage.slot := RULE_BASED_GRAPH_STORAGE_SLOT
        }
    }

    function $graphRulesStorage() private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().graphRulesStorage;
    }

    function $followRulesStorage(address account) private view returns (RulesStorage storage _storage) {
        return $ruleBasedStorage().followRulesStorage[account];
    }

    // Internal

    function _addGraphRule(RuleConfiguration calldata rule) internal {
        $graphRulesStorage().addRule(rule, abi.encodeWithSelector(IGraphRule.configure.selector, rule.configData));
    }

    function _updateGraphRule(RuleConfiguration calldata rule) internal {
        $graphRulesStorage().updateRule(rule, abi.encodeWithSelector(IGraphRule.configure.selector, rule.configData));
    }

    function _removeGraphRule(address rule) internal {
        $graphRulesStorage().removeRule(rule);
    }

    function _addFollowRule(address account, RuleConfiguration calldata rule) internal {
        $followRulesStorage(account).addRule(
            rule, abi.encodeWithSelector(IFollowRule.configure.selector, account, rule.configData)
        );
    }

    function _updateFollowRule(address account, RuleConfiguration calldata rule) internal {
        $followRulesStorage(account).updateRule(
            rule, abi.encodeWithSelector(IFollowRule.configure.selector, account, rule.configData)
        );
    }

    function _removeFollowRule(address account, address rule) internal {
        $followRulesStorage(account).removeRule(rule);
    }

    // TODO: Unfortunately we had to copy-paste this code because we couldn't think of a better solution for encoding yet.

    function _graphProcessFollowRulesChange(
        address account,
        address[] memory followRules,
        RuleExecutionData calldata graphRulesData
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $graphRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $graphRulesStorage().requiredRules[i].call(
                abi.encodeWithSelector(
                    IGraphRule.processFollowRulesChange.selector,
                    account,
                    followRules,
                    graphRulesData.dataForRequiredRules[i]
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($graphRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $graphRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $graphRulesStorage().anyOfRules[i].call(
                abi.encodeWithSelector(
                    IGraphRule.processFollowRulesChange.selector,
                    account,
                    followRules,
                    graphRulesData.dataForAnyOfRules[i]
                )
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the any-of rules failed");
    }

    function _graphProcessFollow(
        address followerAcount,
        address accountToFollow,
        uint256 followId,
        RuleExecutionData calldata graphRulesData
    ) internal {
        _processFollow(
            $graphRulesStorage(),
            IGraphRule.processFollow.selector,
            followerAcount,
            accountToFollow,
            followId,
            graphRulesData
        );
    }

    function _accountProcessFollow(
        address followerAcount,
        address accountToFollow,
        uint256 followId,
        RuleExecutionData calldata followRulesData
    ) internal {
        _processFollow(
            $followRulesStorage(accountToFollow),
            IFollowRule.processFollow.selector,
            followerAcount,
            accountToFollow,
            followId,
            followRulesData
        );
    }

    function _processFollow(
        RulesStorage storage rulesStorage,
        bytes4 selector,
        address followerAcount,
        address accountToFollow,
        uint256 followId,
        RuleExecutionData calldata data
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < rulesStorage.requiredRules.length; i++) {
            (bool callNotReverted,) = rulesStorage.requiredRules[i].call(
                abi.encodeWithSelector(
                    selector, followerAcount, accountToFollow, followId, data.dataForRequiredRules[i]
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($graphRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < rulesStorage.anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = rulesStorage.anyOfRules[i].call(
                abi.encodeWithSelector(selector, followerAcount, accountToFollow, followId, data.dataForAnyOfRules[i])
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the any-of rules failed");
    }

    function _graphProcessUnfollow(
        address unfollowerAccount,
        address accountToUnfollow,
        uint256 followId,
        RuleExecutionData calldata graphRulesData
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $graphRulesStorage().requiredRules.length; i++) {
            (bool callNotReverted,) = $graphRulesStorage().requiredRules[i].call(
                abi.encodeWithSelector(
                    IGraphRule.processUnfollow.selector,
                    unfollowerAccount,
                    accountToUnfollow,
                    followId,
                    graphRulesData.dataForRequiredRules[i]
                )
            );
            require(callNotReverted, "Some required rule failed");
        }
        // Check any-of rules (OR-combined rules)
        if ($graphRulesStorage().anyOfRules.length == 0) {
            return; // If there are no OR-combined rules, we can return
        }
        for (uint256 i = 0; i < $graphRulesStorage().anyOfRules.length; i++) {
            (bool callNotReverted, bytes memory returnData) = $graphRulesStorage().anyOfRules[i].call(
                abi.encodeWithSelector(
                    IGraphRule.processUnfollow.selector,
                    unfollowerAccount,
                    accountToUnfollow,
                    followId,
                    graphRulesData.dataForAnyOfRules[i]
                )
            );
            if (callNotReverted && abi.decode(returnData, (bool))) {
                // Note: abi.decode would fail if call reverted, so don't put this out of the brackets!
                return; // If any of the OR-combined rules passed, it means they succeed and we can return
            }
        }
        revert("All of the any-of rules failed");
    }

    function _getGraphRules(bool isRequired) internal view returns (address[] memory) {
        return $graphRulesStorage().getRulesArray(isRequired);
    }

    function _getFollowRules(address account, bool isRequired) internal view returns (address[] memory) {
        return $followRulesStorage(account).getRulesArray(isRequired);
    }
}
