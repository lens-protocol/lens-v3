// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {CommunityRuleCombinator} from "contracts/primitives/community/CommunityRuleCombinator.sol";
import {IRule} from "contracts/primitives/rules/IRule.sol";
import {ICommunityRule} from "contracts/primitives/community/ICommunityRule.sol";
import {IAccessControl} from "contracts/primitives/access-control/IAccessControl.sol";
import {RuleCombinator} from "contracts/primitives/rules/RuleCombinator.sol"; // Import RuleCombinator to access RuleConfiguration

contract CommunityRuleCombinatorTest is Test {
    CommunityRuleCombinator communityRuleCombinator;
    address owner = makeAddr("OWNER");
    address alice = makeAddr("ALICE");
    address bob = makeAddr("BOB");
    address[] rules;
    address accessControlAddress;

    uint256 constant CHANGE_RULE_ACCESS_CONTROL_RID = uint256(keccak256("CHANGE_RULE_ACCESS_CONTROL"));
    uint256 constant CONFIGURE_RULE_RID = uint256(keccak256("CONFIGURE_RULE"));

    function setUp() public {
        communityRuleCombinator = new CommunityRuleCombinator();
        rules = [makeAddr("RULE_1"), makeAddr("RULE_2")];
        accessControlAddress = makeAddr("ACCESS_CONTROL");

        // Adding mock rules to the CommunityRuleCombinator
        vm.mockCall(rules[0], abi.encodeWithSelector(IRule.configure.selector, ""), abi.encode(true));
        vm.mockCall(rules[1], abi.encodeWithSelector(IRule.configure.selector, ""), abi.encode(true));

        // Step 1: Initialize the RuleCombinator with valid access control and combination mode
        RuleCombinator.Operation operation = RuleCombinator.Operation.INITIALIZE;
        bytes memory initializationData = abi.encode(RuleCombinator.CombinationMode.AND, accessControlAddress, "");

        // Mock the access control check for initialization
        vm.mockCall(
            accessControlAddress,
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, address(0), address(address(0)), 0),
            abi.encode(true)
        );
        vm.mockCall(
            accessControlAddress,
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, owner, address(communityRuleCombinator), 0),
            abi.encode(true)
        );

        // Call configure with the INITIALIZE operation
        bytes memory initializeCallData = abi.encode(operation, initializationData);
        vm.prank(owner);
        communityRuleCombinator.configure(initializeCallData);
    }

    function testAddRules() public {

        // Step 1: Now that the RuleCombinator is initialized, we can proceed with adding rules

        // Mock access control to allow adding rules
        vm.mockCall(
            accessControlAddress,
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, owner, address(communityRuleCombinator), CONFIGURE_RULE_RID),
            abi.encode(true)
        );

        // Prepare rule configuration for adding
        RuleCombinator.RuleConfiguration[] memory ruleConfigs = new RuleCombinator.RuleConfiguration[](2);
        ruleConfigs[0] = RuleCombinator.RuleConfiguration({contractAddress: rules[0], data: ""});
        ruleConfigs[1] = RuleCombinator.RuleConfiguration({contractAddress: rules[1], data: ""});

        // Mock the delegate call for rule configuration
        for (uint256 i = 0; i < ruleConfigs.length; i++) {
            vm.mockCall(
                ruleConfigs[i].contractAddress,
                abi.encodeWithSelector(IRule.configure.selector, ruleConfigs[i].data),
                abi.encode(true)
            );
        }

        // Encode the operation (ADD_RULES) and the rule configurations
        bytes memory configureData = abi.encode(RuleCombinator.Operation.ADD_RULES, abi.encode(ruleConfigs));

        // Call configure with the ADD_RULES operation
        vm.prank(owner);
        communityRuleCombinator.configure(configureData);

        // Assert that the rules were added
        address[] memory addedRules = communityRuleCombinator.getRules();
        assertEq(addedRules[0], rules[0], "Rule 1 should be added");
        assertEq(addedRules[1], rules[1], "Rule 2 should be added");
    }


        
    function testProcessJoining() public {
        bytes[] memory ruleSpecificDatas = new bytes[](2);
        ruleSpecificDatas[0] = "RULE_1_JOINING_DATA";
        ruleSpecificDatas[1] = "RULE_2_JOINING_DATA";

        bytes memory encodedData = abi.encode(ruleSpecificDatas);

        // Call processJoining
        vm.prank(owner);
        communityRuleCombinator.processJoining(owner, alice, encodedData);
    }

    function testProcessLeaving() public {
        bytes[] memory ruleSpecificDatas = new bytes[](2);
        ruleSpecificDatas[0] = "RULE_1_LEAVING_DATA";
        ruleSpecificDatas[1] = "RULE_2_LEAVING_DATA";

        bytes memory encodedData = abi.encode(ruleSpecificDatas);

        // Call processLeaving
        vm.prank(owner);
        communityRuleCombinator.processLeaving(owner, bob, encodedData);
    }

    function testProcessRemoval() public {
        bytes[] memory ruleSpecificDatas = new bytes[](2);
        ruleSpecificDatas[0] = "RULE_1_REMOVAL_DATA";
        ruleSpecificDatas[1] = "RULE_2_REMOVAL_DATA";

        bytes memory encodedData = abi.encode(ruleSpecificDatas);

        // Call processRemoval
        vm.prank(owner);
        communityRuleCombinator.processRemoval(owner, bob, encodedData);
    }

    function testRemoveRules() public {
        testAddRules();

        // Mock access control to allow removing rules
        vm.mockCall(
            accessControlAddress,
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, owner, address(communityRuleCombinator), 0),
            abi.encode(true)
        );

        // Prepare rule configuration for removing
        RuleCombinator.RuleConfiguration[] memory ruleConfigs = new RuleCombinator.RuleConfiguration[](2);
        ruleConfigs[0] = RuleCombinator.RuleConfiguration({contractAddress: rules[0], data: ""});
        ruleConfigs[1] = RuleCombinator.RuleConfiguration({contractAddress: rules[1], data: ""});

        // Mock the delegate call for rule removal
        for (uint256 i = 0; i < ruleConfigs.length; i++) {
            vm.mockCall(
                ruleConfigs[i].contractAddress,
                abi.encodeWithSelector(IRule.configure.selector, ruleConfigs[i].data),
                abi.encode(true)
            );
        }

        // Encode the operation (REMOVE_RULES) and the rule configurations
        bytes memory configureData = abi.encode(RuleCombinator.Operation.REMOVE_RULES, abi.encode(ruleConfigs));

        // Call configure with the REMOVE_RULES operation
        vm.prank(owner);
        communityRuleCombinator.configure(configureData);

        // Assert that the rules were removed
        address[] memory addedRules = communityRuleCombinator.getRules();
        assertEq(addedRules.length, 0, "All rules should be removed");
    }
}