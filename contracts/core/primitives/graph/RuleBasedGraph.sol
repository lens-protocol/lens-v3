// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IFollowRule} from "./../../interfaces/IFollowRule.sol";
import {IGraphRule} from "./../../interfaces/IGraphRule.sol";
import {RulesStorage, RulesLib} from "./../../libraries/RulesLib.sol";
import {
    RuleProcessingParams, RuleConfigurationChange, RuleSelectorChange, Rule, KeyValue
} from "./../../types/Types.sol";
import {IGraph} from "./../../interfaces/IGraph.sol";
import {RuleBasedPrimitive} from "./../../base/RuleBasedPrimitive.sol";

abstract contract RuleBasedGraph is IGraph, RuleBasedPrimitive {
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

    ////////////////////////////  CONFIGURATION FUNCTIONS  ////////////////////////////

    function changeGraphRules(
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges
    ) external virtual override {
        _changePrimitiveRules($graphRulesStorage(), configChanges, selectorChanges);
    }

    function changeFollowRules(
        address account,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        RuleProcessingParams[] calldata ruleChangesProcessingParams
    ) external virtual override {
        _changeEntityRules(
            $followRulesStorage(account),
            uint256(uint160(account)),
            configChanges,
            selectorChanges,
            ruleChangesProcessingParams
        );
    }

    function _supportedPrimitiveRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = IGraphRule.processFollow.selector;
        selectors[1] = IGraphRule.processUnfollow.selector;
        selectors[2] = IGraphRule.processFollowRuleChanges.selector;
        return selectors;
    }

    function _supportedEntityRuleSelectors() internal view virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IFollowRule.processFollow.selector;
        return selectors;
    }

    function _encodePrimitiveConfigureCall(
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal pure override returns (bytes memory) {
        return abi.encodeCall(IGraphRule.configure, (configSalt, ruleParams));
    }

    function _emitPrimitiveRuleConfiguredEvent(
        bool wasAlreadyConfigured,
        address ruleAddress,
        bytes32 configSalt,
        KeyValue[] calldata ruleParams
    ) internal override {
        if (wasAlreadyConfigured) {
            emit IGraph.Lens_Graph_RuleReconfigured(ruleAddress, configSalt, ruleParams);
        } else {
            emit IGraph.Lens_Graph_RuleConfigured(ruleAddress, configSalt, ruleParams);
        }
    }

    function _emitPrimitiveRuleSelectorEvent(
        bool enabled,
        address ruleAddress,
        bytes32 configSalt,
        bool isRequired,
        bytes4 ruleSelector
    ) internal override {
        if (enabled) {
            emit Lens_Graph_RuleSelectorEnabled(ruleAddress, configSalt, isRequired, ruleSelector);
        } else {
            emit Lens_Graph_RuleSelectorDisabled(ruleAddress, configSalt, isRequired, ruleSelector);
        }
    }

    function _amountOfRules(bytes4 ruleSelector) internal view returns (uint256) {
        return $graphRulesStorage()._getRulesArray(ruleSelector, false).length
            + $graphRulesStorage()._getRulesArray(ruleSelector, true).length;
    }

    function getGraphRules(
        bytes4 ruleSelector,
        bool isRequired
    ) external view virtual override returns (Rule[] memory) {
        return $graphRulesStorage()._getRulesArray(ruleSelector, isRequired);
    }

    function getFollowRules(
        address account,
        bytes4 ruleSelector,
        bool isRequired
    ) external view virtual override returns (Rule[] memory) {
        return $followRulesStorage(account)._getRulesArray(ruleSelector, isRequired);
    }

    // Internal

    function _graphProcessFollowRuleChanges(
        address account,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
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
                    ruleCustomParams = graphRulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = rule.addr.call(
                    abi.encodeCall(
                        IGraphRule.processFollowRuleChanges,
                        (rule.configSalt, account, configChanges, selectorChanges, ruleCustomParams)
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
                    ruleCustomParams = graphRulesProcessingParams[j].ruleParams;
                }
                (bool callNotReverted,) = rule.addr.call(
                    abi.encodeCall(
                        IGraphRule.processFollowRuleChanges,
                        (rule.configSalt, account, configChanges, selectorChanges, ruleCustomParams)
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
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
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
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
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
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
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
                    ruleCustomParams = rulesProcessingParams[j].ruleParams;
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
}
