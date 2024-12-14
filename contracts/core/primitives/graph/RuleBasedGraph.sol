// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IFollowRule} from "./../../interfaces/IFollowRule.sol";
import {IGraphRule} from "./../../interfaces/IGraphRule.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {
    RuleChange,
    RuleProcessingParams,
    RuleConfigurationParams,
    RuleConfigurationParams_Multiselector,
    Rule,
    RuleOperation,
    KeyValue
} from "./../../types/Types.sol";
import {IGraph} from "./../../interfaces/IGraph.sol";

abstract contract RuleBasedGraph is IGraph {
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

    function changeGraphRules(RuleChange[] calldata ruleChanges) external override {
        _beforeChangeGraphRules(ruleChanges);
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleConfigurationParams_Multiselector memory ruleConfig_Multiselector = ruleChanges[i].configuration;
            for (uint256 j = 0; j < ruleConfig_Multiselector.ruleSelectors.length; j++) {
                RuleConfigurationParams memory ruleConfig = RuleConfigurationParams({
                    ruleSelector: ruleConfig_Multiselector.ruleSelectors[j],
                    ruleAddress: ruleConfig_Multiselector.ruleAddress,
                    isRequired: ruleConfig_Multiselector.isRequired,
                    configSalt: ruleConfig_Multiselector.configSalt,
                    customParams: ruleConfig_Multiselector.customParams
                });

                if (ruleChanges[i].operation == RuleOperation.ADD) {
                    _addGraphRule(ruleConfig);
                    emit Lens_Graph_RuleAdded(
                        ruleConfig.ruleAddress,
                        ruleConfig.configSalt,
                        ruleConfig.ruleSelector,
                        ruleConfig.customParams,
                        ruleConfig.isRequired
                    );
                } else if (ruleChanges[i].operation == RuleOperation.UPDATE) {
                    _updateGraphRule(ruleConfig);
                    emit Lens_Graph_RuleUpdated(
                        ruleConfig.ruleAddress,
                        ruleConfig.configSalt,
                        ruleConfig.ruleSelector,
                        ruleConfig.customParams,
                        ruleConfig.isRequired
                    );
                } else {
                    _removeGraphRule(ruleConfig);
                    emit Lens_Graph_RuleRemoved(ruleConfig.ruleAddress, ruleConfig.configSalt, ruleConfig.ruleSelector);
                }
            }
        }
        require(
            $graphRulesStorage().anyOfRules[IGraphRule.processFollow.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
        require(
            $graphRulesStorage().anyOfRules[IGraphRule.processFollowRuleChanges.selector].length != 1,
            "Cannot have exactly one single any-of rule"
        );
    }

    function changeFollowRules(
        address account,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] calldata graphRulesProcessingParams
    ) external override {
        // TODO: Decide if we want a PID to skip checks for owners/admins
        // require(msg.sender == account || _hasAccess(SKIP_FOLLOW_RULES_CHECKS_PID));
        require(msg.sender == account);
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleConfigurationParams_Multiselector memory ruleConfig_Multiselector = ruleChanges[i].configuration;
            for (uint256 j = 0; j < ruleConfig_Multiselector.ruleSelectors.length; j++) {
                RuleConfigurationParams memory ruleConfig = RuleConfigurationParams({
                    ruleSelector: ruleConfig_Multiselector.ruleSelectors[j],
                    ruleAddress: ruleConfig_Multiselector.ruleAddress,
                    isRequired: ruleConfig_Multiselector.isRequired,
                    configSalt: ruleConfig_Multiselector.configSalt,
                    customParams: ruleConfig_Multiselector.customParams
                });

                if (ruleChanges[i].operation == RuleOperation.ADD) {
                    _addFollowRule(account, ruleConfig);
                    emit Lens_Graph_Follow_RuleAdded(
                        account,
                        ruleConfig.ruleAddress,
                        ruleConfig.configSalt,
                        ruleConfig.ruleSelector,
                        ruleConfig.customParams,
                        ruleConfig.isRequired
                    );
                } else if (ruleChanges[i].operation == RuleOperation.UPDATE) {
                    _updateFollowRule(account, ruleConfig);
                    emit Lens_Graph_Follow_RuleUpdated(
                        account,
                        ruleConfig.ruleAddress,
                        ruleConfig.configSalt,
                        ruleConfig.ruleSelector,
                        ruleConfig.customParams,
                        ruleConfig.isRequired
                    );
                } else {
                    _removeFollowRule(account, ruleConfig);
                    emit Lens_Graph_Follow_RuleRemoved(
                        account, ruleConfig.ruleAddress, ruleConfig.configSalt, ruleConfig.ruleSelector
                    );
                }
            }
        }

        // if (_hasAccess(SKIP_FOLLOW_RULES_CHECKS_PID)) {
        //     return; // Skip processing the graph rules if you have the right access
        // }
        _graphProcessFollowRuleChanges(account, ruleChanges, graphRulesProcessingParams);
    }

    function getGraphRules(bytes4 ruleSelector, bool isRequired) external view override returns (Rule[] memory) {
        return $graphRulesStorage()._getRulesArray(ruleSelector, isRequired);
    }

    function getFollowRules(
        address account,
        bytes4 ruleSelector,
        bool isRequired
    ) external view override returns (Rule[] memory) {
        return $followRulesStorage(account)._getRulesArray(ruleSelector, isRequired);
    }

    // Internal

    function _beforeChangeGraphRules(RuleChange[] calldata ruleChanges) internal virtual {}

    function _addGraphRule(RuleConfigurationParams memory rule) internal {
        $graphRulesStorage().addRule(
            rule, abi.encodeCall(IGraphRule.configure, (rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _updateGraphRule(RuleConfigurationParams memory rule) internal {
        $graphRulesStorage().updateRule(
            rule, abi.encodeCall(IGraphRule.configure, (rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _removeGraphRule(RuleConfigurationParams memory rule) internal {
        $graphRulesStorage().removeRule(rule);
    }

    function _addFollowRule(address account, RuleConfigurationParams memory rule) internal {
        $followRulesStorage(account).addRule(
            rule, abi.encodeCall(IFollowRule.configure, (account, rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _updateFollowRule(address account, RuleConfigurationParams memory rule) internal {
        $followRulesStorage(account).updateRule(
            rule, abi.encodeCall(IFollowRule.configure, (account, rule.ruleSelector, rule.configSalt, rule.customParams))
        );
    }

    function _removeFollowRule(address account, RuleConfigurationParams memory rule) internal {
        $followRulesStorage(account).removeRule(rule);
    }

    // TODO: Unfortunately we had to copy-paste this code because we couldn't think of a better solution for encoding yet.

    function _graphProcessFollowRuleChanges(
        address account,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] calldata graphRulesProcessingParams
    ) internal {
        bytes4 ruleSelector = IGraphRule.processFollowRuleChanges.selector;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < $graphRulesStorage().requiredRules[ruleSelector].length; i++) {
            Rule memory rule = $graphRulesStorage().requiredRules[ruleSelector][i];
            for (uint256 j = 0; j < graphRulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    graphRulesProcessingParams[j].ruleAddress == rule.addr
                        && graphRulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = graphRulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = rule.addr.call(
                    abi.encodeCall(
                        IGraphRule.processFollowRuleChanges, (rule.configSalt, account, ruleChanges, ruleCustomParams)
                    )
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        // Check any-of rules (OR-combined rules)
        for (uint256 i = 0; i < $graphRulesStorage().anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = $graphRulesStorage().anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < graphRulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    graphRulesProcessingParams[j].ruleAddress == rule.addr
                        && graphRulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = graphRulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = rule.addr.call(
                    abi.encodeCall(
                        IGraphRule.processFollowRuleChanges, (rule.configSalt, account, ruleChanges, ruleCustomParams)
                    )
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($graphRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }

    function _encodeAndCallGraphProcessFollow(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IGraphRule.processFollow,
                (
                    configSalt,
                    originalMsgSender,
                    followerAccount,
                    accountToFollow,
                    primitiveCustomParams,
                    ruleCustomParams
                )
            )
        );
    }

    function _graphProcessFollow(
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) internal {
        _processFollow(
            $graphRulesStorage(),
            _encodeAndCallGraphProcessFollow,
            IGraphRule.processFollow.selector,
            originalMsgSender,
            followerAccount,
            accountToFollow,
            primitiveCustomParams,
            ruleProcessingParams
        );
    }

    function _encodeAndCallGraphProcessUnfollow(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IGraphRule.processUnfollow,
                (
                    configSalt,
                    originalMsgSender,
                    followerAccount,
                    accountToUnfollow,
                    primitiveCustomParams,
                    ruleCustomParams
                )
            )
        );
    }

    function _graphProcessUnfollow(
        address originalMsgSender,
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) internal {
        _processUnfollow(
            $graphRulesStorage(),
            _encodeAndCallGraphProcessUnfollow,
            originalMsgSender,
            followerAccount,
            accountToUnfollow,
            primitiveCustomParams,
            ruleProcessingParams
        );
    }

    function _encodeAndCallAccountProcessFollow(
        address rule,
        bytes32 configSalt,
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveCustomParams,
        KeyValue[] memory ruleCustomParams
    ) internal returns (bool, bytes memory) {
        return rule.call(
            abi.encodeCall(
                IFollowRule.processFollow,
                (
                    configSalt,
                    originalMsgSender,
                    followerAccount,
                    accountToFollow,
                    primitiveCustomParams,
                    ruleCustomParams
                )
            )
        );
    }

    function _accountProcessFollow(
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) internal {
        _processFollow(
            $followRulesStorage(accountToFollow),
            _encodeAndCallAccountProcessFollow,
            IFollowRule.processFollow.selector,
            originalMsgSender,
            followerAccount,
            accountToFollow,
            primitiveCustomParams,
            ruleProcessingParams
        );
    }

    function _processUnfollow(
        RulesStorage storage rulesStorage,
        function(address,bytes32,address,address,address,KeyValue[] calldata,KeyValue[] memory) internal returns (bool,bytes memory)
            encodeAndCall,
        address originalMsgSender,
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        bytes4 ruleSelector = IGraphRule.processUnfollow.selector;
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < rulesStorage.requiredRules[ruleSelector].length; i++) {
            Rule memory rule = rulesStorage.requiredRules[ruleSelector][i];
            // TODO: Think how to put this loop into a library (all the rules use it)
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr,
                    rule.configSalt,
                    originalMsgSender,
                    followerAccount,
                    accountToUnfollow,
                    primitiveCustomParams,
                    ruleCustomParams
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        for (uint256 i = 0; i < rulesStorage.anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = rulesStorage.anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr,
                    rule.configSalt,
                    originalMsgSender,
                    followerAccount,
                    accountToUnfollow,
                    primitiveCustomParams,
                    ruleCustomParams
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($graphRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }

    function _processFollow(
        RulesStorage storage rulesStorage,
        function(address,bytes32,address,address,address,KeyValue[] calldata,KeyValue[] memory) internal returns (bool,bytes memory)
            encodeAndCall,
        bytes4 ruleSelector,
        address originalMsgSender,
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata primitiveCustomParams,
        RuleProcessingParams[] calldata rulesProcessingParams
    ) internal {
        // Check required rules (AND-combined rules)
        for (uint256 i = 0; i < rulesStorage.requiredRules[ruleSelector].length; i++) {
            Rule memory rule = rulesStorage.requiredRules[ruleSelector][i];
            // TODO: Think how to put this loop into a library (all the rules use it)
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr,
                    rule.configSalt,
                    originalMsgSender,
                    followerAccount,
                    accountToFollow,
                    primitiveCustomParams,
                    ruleCustomParams
                );
                require(callNotReverted, "Some required rule failed");
            }
        }
        for (uint256 i = 0; i < rulesStorage.anyOfRules[ruleSelector].length; i++) {
            Rule memory rule = rulesStorage.anyOfRules[ruleSelector][i];
            for (uint256 j = 0; j < rulesProcessingParams.length; j++) {
                KeyValue[] memory ruleCustomParams = new KeyValue[](0);
                if (
                    rulesProcessingParams[j].ruleAddress == rule.addr
                        && rulesProcessingParams[j].configSalt == rule.configSalt
                ) {
                    ruleCustomParams = rulesProcessingParams[j].customParams;
                }
                (bool callNotReverted,) = encodeAndCall(
                    rule.addr,
                    rule.configSalt,
                    originalMsgSender,
                    followerAccount,
                    accountToFollow,
                    primitiveCustomParams,
                    ruleCustomParams
                );
                if (callNotReverted) {
                    return; // If any of the OR-combined rules passed, it means they succeed and we can return
                }
            }
        }
        // If there are any-of rules and it reached this point, it means all of them failed.
        require($graphRulesStorage().anyOfRules[ruleSelector].length > 0, "All of the any-of rules failed");
    }

    function _amountOfRules(bytes4 ruleSelector) internal view returns (uint256) {
        return $graphRulesStorage()._getRulesArray(ruleSelector, false).length
            + $graphRulesStorage()._getRulesArray(ruleSelector, true).length;
    }
}
