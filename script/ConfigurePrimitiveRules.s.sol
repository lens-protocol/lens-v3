// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {RuleChange, RuleSelectorChange, RuleConfigurationChange, KeyValue, Rule} from "contracts/core/types/Types.sol";
import {IAccessControlled} from "contracts/core/interfaces/IAccessControlled.sol";

import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";

import {IGraph} from "contracts/core/interfaces/IGraph.sol";
import {IGraphRule} from "contracts/core/interfaces/IGraphRule.sol";

import {INamespace} from "contracts/core/interfaces/INamespace.sol";
import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";

/// @dev Run this script using the following command:
///   forge script script/ConfigurePrimitiveRules.s.sol --rpc-url https://api.lens.matterhosted.dev/ --zksync -vvvvv
/// Then add the --broadcast flag to actually send the transactions to the network.
contract ConfigurePrimitiveRules is Script {
    address constant LENS_GLOBAL_NAMESPACE = address(0x1aA55B9042f08f45825dC4b651B64c9F98Af4615);
    address constant LENS_GLOBAL_FEED = address(0xcB5E109FFC0E15565082d78E68dDDf2573703580);
    address constant LENS_GLOBAL_GRAPH = address(0x433025d9718302E7B2e1853D712d96F00764513F);

    address constant ACCOUNT_BLOCKING_RULE = address(0x3B766408f14141F4B567681A1c29CFB58D1C1574);

    address constant USERNAME_SIMPLE_CHARSET_NAMESPACE_RULE = address(0x5DBE2054903512ff26E336C0cBdEd6E0DDBEAc4F);
    address constant USERNAME_RESERVED_NAMESPACE_RULE = address(0x0E8B9960f2a891A561f2d52F0Cd98cCA19CDF8c9);
    address constant USERNAME_LENGTH_NAMESPACE_RULE = address(0xb541055222C87EE86A72558e8B582a9C0158A0d8);

    function testConfigurePrimitiveRules() public {
        // Prevents being counted in Foundry Coverage
    }

    function run() external {
        uint256 pk = vm.envUint("WALLET_PRIVATE_KEY");

        _logRules();

        vm.startBroadcast(pk);

        _changeNamespaceRules();
        _changeFeedRules();
        _changeGraphRules();

        vm.stopBroadcast();

        _logRules();
    }

    function _logRules() internal view {
        console.log("- - - - - - - -");

        Rule[] memory namespaceRules =
            INamespace(LENS_GLOBAL_NAMESPACE).getNamespaceRules(INamespaceRule.processCreation.selector, true);
        if (namespaceRules.length == 0) {
            console.log("No namespace rules found");
        }
        for (uint256 i = 0; i < namespaceRules.length; i++) {
            console.log("Namespace rule address < %s >: %s", i, namespaceRules[i].ruleAddress);
        }

        console.log("- - - - - - - -");

        Rule[] memory feedRules = IFeed(LENS_GLOBAL_FEED).getFeedRules(IFeedRule.processCreatePost.selector, true);
        if (namespaceRules.length == 0) {
            console.log("No feed rules found");
        }
        for (uint256 i = 0; i < feedRules.length; i++) {
            console.log("Feed rule address < %s >: %s", i, feedRules[i].ruleAddress);
        }

        console.log("- - - - - - - -");

        Rule[] memory graphRules = IGraph(LENS_GLOBAL_GRAPH).getGraphRules(IGraphRule.processFollow.selector, true);
        if (namespaceRules.length == 0) {
            console.log("No graph rules found");
        }
        for (uint256 i = 0; i < graphRules.length; i++) {
            console.log("Graph rule address < %s >: %s", i, graphRules[i].ruleAddress);
        }

        console.log("- - - - - - - -");
    }

    function _changeNamespaceRules() internal {
        address accessControl = address(IAccessControlled(LENS_GLOBAL_NAMESPACE).getAccessControl());

        RuleSelectorChange[] memory selectorChanges = new RuleSelectorChange[](1);
        // All rules are using the same selector changes in this case.
        selectorChanges[0] =
            RuleSelectorChange({ruleSelector: INamespaceRule.processCreation.selector, isRequired: true, enabled: true});

        RuleChange[] memory ruleChanges = new RuleChange[](3);

        ruleChanges[0] = RuleChange({
            ruleAddress: USERNAME_SIMPLE_CHARSET_NAMESPACE_RULE,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: selectorChanges
        });

        KeyValue[] memory reservedRuleParams = new KeyValue[](1);
        reservedRuleParams[0] = KeyValue({key: keccak256("lens.param.accessControl"), value: abi.encode(accessControl)});

        ruleChanges[1] = RuleChange({
            ruleAddress: USERNAME_RESERVED_NAMESPACE_RULE,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: reservedRuleParams}),
            selectorChanges: selectorChanges
        });

        KeyValue[] memory lengthRuleParams = new KeyValue[](3);
        lengthRuleParams[0] = KeyValue({key: keccak256("lens.param.accessControl"), value: abi.encode(accessControl)});
        lengthRuleParams[1] = KeyValue({key: keccak256("lens.param.minLength"), value: abi.encode(uint8(5))});
        lengthRuleParams[2] = KeyValue({key: keccak256("lens.param.maxLength"), value: abi.encode(uint8(26))});

        ruleChanges[2] = RuleChange({
            ruleAddress: USERNAME_LENGTH_NAMESPACE_RULE,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: lengthRuleParams}),
            selectorChanges: selectorChanges
        });

        console.log("Changing namespace rules...");

        INamespace(LENS_GLOBAL_NAMESPACE).changeNamespaceRules(ruleChanges);
    }

    function _changeFeedRules() internal {
        RuleSelectorChange[] memory selectorChanges = new RuleSelectorChange[](1);
        selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IFeedRule.processCreatePost.selector, isRequired: true, enabled: true});

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: ACCOUNT_BLOCKING_RULE,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: selectorChanges
        });

        console.log("Changing feed rules...");

        IFeed(LENS_GLOBAL_FEED).changeFeedRules(ruleChanges);
    }

    function _changeGraphRules() internal {
        RuleSelectorChange[] memory selectorChanges = new RuleSelectorChange[](1);
        selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IGraphRule.processFollow.selector, isRequired: true, enabled: true});

        RuleChange[] memory ruleChanges = new RuleChange[](1);
        ruleChanges[0] = RuleChange({
            ruleAddress: ACCOUNT_BLOCKING_RULE,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: selectorChanges
        });

        console.log("Changing graph rules...");

        IGraph(LENS_GLOBAL_GRAPH).changeGraphRules(ruleChanges);
    }
}
