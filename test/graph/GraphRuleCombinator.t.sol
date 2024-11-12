// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {
    GraphRuleCombinator, RuleCombinator, IFollowRule
} from "../../contracts/primitives/graph/GraphRuleCombinator.sol";
import {OwnerOnlyAccessControl} from "../../contracts/primitives/access-control/OwnerOnlyAccessControl.sol";
import {MockGraphRule} from "../mock/MockGraphRule.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GraphRuleCombinatorTest is Test {
    GraphRuleCombinator public combinator;
    OwnerOnlyAccessControl public accessControl;
    MockGraphRule public rule1;
    MockGraphRule public rule2;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    // Events from MockGraphRule
    event ProcessFollowCalled(address followerAccount, address targetAccount, uint256 followId, bytes graphRulesData);
    event ProcessUnfollowCalled(
        address unfollowerAccount, address unfollowedAccount, uint256 unfollowId, bytes graphRulesData
    );
    event ProcessFollowRulesChangeCalled(address account, IFollowRule followRules, bytes data);
    event ProcessBlockCalled(address account, bytes data);
    event ProcessUnblockCalled(address account, bytes data);

    function setUp() public {
        vm.startPrank(owner);
        accessControl = new OwnerOnlyAccessControl(owner);
        address impl = address(new GraphRuleCombinator());
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), "");
        combinator = GraphRuleCombinator(address(proxy));
        rule1 = new MockGraphRule();
        rule2 = new MockGraphRule();
        vm.stopPrank();
    }

    function testInitialize() public {
        vm.startPrank(owner);
        bytes memory initData = abi.encode(RuleCombinator.CombinationMode.AND, address(accessControl), "");
        combinator.configure(abi.encode(RuleCombinator.Operation.INITIALIZE, initData));
        vm.stopPrank();

        assertEq(address(combinator.getAccessControl()), address(accessControl));
        assertEq(uint256(combinator.getCombinationMode()), uint256(RuleCombinator.CombinationMode.AND));
    }

    function testAddRules() public {
        // First initialize
        vm.startPrank(owner);
        bytes memory initData = abi.encode(RuleCombinator.CombinationMode.AND, address(accessControl), "");
        combinator.configure(abi.encode(RuleCombinator.Operation.INITIALIZE, initData));

        // Then add rules
        RuleCombinator.RuleConfiguration[] memory rules = new RuleCombinator.RuleConfiguration[](2);
        rules[0] = RuleCombinator.RuleConfiguration(address(rule1), "");
        rules[1] = RuleCombinator.RuleConfiguration(address(rule2), "");

        bytes memory addRulesData = abi.encode(rules);
        combinator.configure(abi.encode(RuleCombinator.Operation.ADD_RULES, addRulesData));
        vm.stopPrank();

        address[] memory addedRules = combinator.getRules();
        assertEq(addedRules.length, 2);
        assertEq(addedRules[0], address(rule1));
        assertEq(addedRules[1], address(rule2));
    }

    function testProcessFollowANDMode() public {
        // Initialize and add rules
        vm.startPrank(owner);
        bytes memory initData = abi.encode(RuleCombinator.CombinationMode.AND, address(accessControl), "");
        combinator.configure(abi.encode(RuleCombinator.Operation.INITIALIZE, initData));

        RuleCombinator.RuleConfiguration[] memory rules = new RuleCombinator.RuleConfiguration[](2);
        rules[0] = RuleCombinator.RuleConfiguration(address(rule1), "");
        rules[1] = RuleCombinator.RuleConfiguration(address(rule2), "");

        bytes memory addRulesData = abi.encode(rules);
        combinator.configure(abi.encode(RuleCombinator.Operation.ADD_RULES, addRulesData));
        vm.stopPrank();

        // Test process follow
        bytes[] memory rulesData = new bytes[](2);
        rulesData[0] = "data1";
        rulesData[1] = "data2";
        bytes memory data = abi.encode(rulesData);

        // Events from MockGraphRule
        vm.expectEmit();
        emit ProcessFollowCalled(user1, user2, 1, "data1");
        vm.expectEmit();
        emit ProcessFollowCalled(user1, user2, 1, "data2");
        combinator.processFollow(user1, user1, user2, 1, data);
    }

    function testProcessUnfollowANDMode() public {
        // Initialize and add rules
        vm.startPrank(owner);
        bytes memory initData = abi.encode(RuleCombinator.CombinationMode.AND, address(accessControl), "");
        combinator.configure(abi.encode(RuleCombinator.Operation.INITIALIZE, initData));

        RuleCombinator.RuleConfiguration[] memory rules = new RuleCombinator.RuleConfiguration[](2);
        rules[0] = RuleCombinator.RuleConfiguration(address(rule1), "");
        rules[1] = RuleCombinator.RuleConfiguration(address(rule2), "");

        bytes memory addRulesData = abi.encode(rules);
        combinator.configure(abi.encode(RuleCombinator.Operation.ADD_RULES, addRulesData));
        vm.stopPrank();

        // Test process unfollow
        bytes[] memory rulesData = new bytes[](2);
        rulesData[0] = "data1";
        rulesData[1] = "data2";
        bytes memory data = abi.encode(rulesData);

        // Events from MockGraphRule
        vm.expectEmit();
        emit ProcessUnfollowCalled(user1, user2, 1, "data1");
        vm.expectEmit();
        emit ProcessUnfollowCalled(user1, user2, 1, "data2");
        combinator.processUnfollow(user1, user1, user2, 1, data);
    }

    function testProcessFollowRulesChangeANDMode() public {
        // Initialize and add rules
        vm.startPrank(owner);
        bytes memory initData = abi.encode(RuleCombinator.CombinationMode.AND, address(accessControl), "");
        combinator.configure(abi.encode(RuleCombinator.Operation.INITIALIZE, initData));

        RuleCombinator.RuleConfiguration[] memory rules = new RuleCombinator.RuleConfiguration[](2);
        rules[0] = RuleCombinator.RuleConfiguration(address(rule1), "");
        rules[1] = RuleCombinator.RuleConfiguration(address(rule2), "");

        bytes memory addRulesData = abi.encode(rules);
        combinator.configure(abi.encode(RuleCombinator.Operation.ADD_RULES, addRulesData));
        vm.stopPrank();

        // Test process follow rules change
        IFollowRule mockFollowRule = IFollowRule(address(0x123));
        bytes[] memory rulesData = new bytes[](2);
        rulesData[0] = "data1";
        rulesData[1] = "data2";
        bytes memory data = abi.encode(rulesData);

        // Events from MockGraphRule
        vm.expectEmit();
        emit ProcessFollowRulesChangeCalled(user1, mockFollowRule, "data1");
        vm.expectEmit();
        emit ProcessFollowRulesChangeCalled(user1, mockFollowRule, "data2");
        combinator.processFollowRulesChange(user1, mockFollowRule, data);
    }

    function testProcessFollowORMode() public {
        // Initialize and add rules
        vm.startPrank(owner);
        bytes memory initData = abi.encode(RuleCombinator.CombinationMode.OR, address(accessControl), "");
        combinator.configure(abi.encode(RuleCombinator.Operation.INITIALIZE, initData));

        RuleCombinator.RuleConfiguration[] memory rules = new RuleCombinator.RuleConfiguration[](2);
        rules[0] = RuleCombinator.RuleConfiguration(address(rule1), "");
        rules[1] = RuleCombinator.RuleConfiguration(address(rule2), "");

        bytes memory addRulesData = abi.encode(rules);
        combinator.configure(abi.encode(RuleCombinator.Operation.ADD_RULES, addRulesData));
        vm.stopPrank();

        // Test process follow
        bytes[] memory rulesData = new bytes[](2);
        rulesData[0] = "data1";
        rulesData[1] = "data2";
        bytes memory data = abi.encode(rulesData);

        // Expect only the first rule to be called in OR mode
        vm.expectEmit();
        emit ProcessFollowCalled(user1, user2, 1, "data1");
        combinator.processFollow(user1, user1, user2, 1, data);
    }

    function testProcessUnfollowORMode() public {
        // Initialize and add rules
        vm.startPrank(owner);
        bytes memory initData = abi.encode(RuleCombinator.CombinationMode.OR, address(accessControl), "");
        combinator.configure(abi.encode(RuleCombinator.Operation.INITIALIZE, initData));

        RuleCombinator.RuleConfiguration[] memory rules = new RuleCombinator.RuleConfiguration[](2);
        rules[0] = RuleCombinator.RuleConfiguration(address(rule1), "");
        rules[1] = RuleCombinator.RuleConfiguration(address(rule2), "");

        bytes memory addRulesData = abi.encode(rules);
        combinator.configure(abi.encode(RuleCombinator.Operation.ADD_RULES, addRulesData));
        vm.stopPrank();

        // Test process unfollow
        bytes[] memory rulesData = new bytes[](2);
        rulesData[0] = "data1";
        rulesData[1] = "data2";
        bytes memory data = abi.encode(rulesData);

        // Expect only the first rule to be called in OR mode
        vm.expectEmit();
        emit ProcessUnfollowCalled(user1, user2, 1, "data1");
        combinator.processUnfollow(user1, user1, user2, 1, data);
    }

    function testProcessFollowRulesChangeORMode() public {
        // Initialize and add rules
        vm.startPrank(owner);
        bytes memory initData = abi.encode(RuleCombinator.CombinationMode.OR, address(accessControl), "");
        combinator.configure(abi.encode(RuleCombinator.Operation.INITIALIZE, initData));

        RuleCombinator.RuleConfiguration[] memory rules = new RuleCombinator.RuleConfiguration[](2);
        rules[0] = RuleCombinator.RuleConfiguration(address(rule1), "");
        rules[1] = RuleCombinator.RuleConfiguration(address(rule2), "");

        bytes memory addRulesData = abi.encode(rules);
        combinator.configure(abi.encode(RuleCombinator.Operation.ADD_RULES, addRulesData));
        vm.stopPrank();

        // Test process follow rules change
        IFollowRule mockFollowRule = IFollowRule(address(0x123));
        bytes[] memory rulesData = new bytes[](2);
        rulesData[0] = "data1";
        rulesData[1] = "data2";
        bytes memory data = abi.encode(rulesData);

        // Expect only the first rule to be called in OR mode
        vm.expectEmit();
        emit ProcessFollowRulesChangeCalled(user1, mockFollowRule, "data1");
        combinator.processFollowRulesChange(user1, mockFollowRule, data);
    }
}
