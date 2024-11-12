// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {Graph, Follow} from "../../../contracts/primitives/graph/Graph.sol";
import {IGraphRule} from "../../../contracts/primitives/graph/IGraphRule.sol";
import {IFollowRule} from "../../../contracts/primitives/graph/IFollowRule.sol";
import {OwnerOnlyAccessControl} from "../../../contracts/primitives/access-control/OwnerOnlyAccessControl.sol";
import {
    AddressBasedAccessControl,
    IRoleBasedAccessControl
} from "../../../contracts/primitives/access-control/AddressBasedAccessControl.sol";
import {RuleConfiguration, RuleExecutionData, DataElement} from "../../../contracts/types/Types.sol";
import {MockGraphRule} from "./mock/MockGraphRule.sol";
import {MockFollowRule} from "./mock/MockFollowRule.sol";

contract GraphTest is Test {
    Graph public graph;
    AddressBasedAccessControl public addressBasedAccessControl;
    OwnerOnlyAccessControl public ownerOnlyAccessControl;
    MockGraphRule public mockGraphRule1;
    MockGraphRule public mockGraphRule2;
    MockFollowRule public mockFollowRule1;
    MockFollowRule public mockFollowRule2;

    address public owner = address(1);
    address public adminSetRules = address(2);
    address public adminSetMetadata = address(3);
    address public addminSetExtraData = address(4);
    address public user1 = address(5);
    address public user2 = address(6);
    address public user3 = address(7);

    uint256 constant SET_RULES_RID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_RID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_RID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant SET_ACCESS_CONTROL_RID = uint256(keccak256("SET_ACCESS_CONTROL"));

    event Lens_Graph_RuleAdded(address indexed ruleAddress, bytes configData, bool indexed isRequired);
    event Lens_Graph_RuleUpdated(address indexed ruleAddress, bytes configData, bool indexed isRequired);
    event Lens_Graph_RuleRemoved(address indexed ruleAddress);

    event Lens_Graph_Follow_RuleAdded(
        address indexed account, address indexed ruleAddress, RuleConfiguration ruleConfiguration
    );

    event Lens_Graph_Follow_RuleUpdated(
        address indexed account, address indexed ruleAddress, RuleConfiguration ruleConfiguration
    );

    event Lens_Graph_Follow_RuleRemoved(address indexed account, address indexed ruleAddress);

    event Lens_Graph_Followed(
        address indexed followerAccount,
        address indexed accountToFollow,
        uint256 followId,
        RuleExecutionData graphRulesData,
        RuleExecutionData followRulesData
    );

    event Lens_Graph_Unfollowed(
        address indexed followerAccount,
        address indexed accountToUnfollow,
        uint256 followId,
        RuleExecutionData graphRulesData
    );

    event Lens_Graph_ExtraDataSet(bytes32 indexed key, bytes value, bytes indexed valueIndexed);

    event Lens_Graph_MetadataURISet(string metadataURI);

    function setUp() public {
        vm.startPrank(owner);
        addressBasedAccessControl = new AddressBasedAccessControl(owner);
        ownerOnlyAccessControl = new OwnerOnlyAccessControl(owner);
        // Set up roles
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(owner)), SET_ACCESS_CONTROL_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, ""
        );

        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(adminSetRules)), SET_RULES_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, ""
        );
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(adminSetMetadata)), SET_METADATA_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, ""
        );
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(addminSetExtraData)),
            SET_EXTRA_DATA_RID,
            IRoleBasedAccessControl.AccessPermission.GRANTED,
            ""
        );
        graph = new Graph("test-graph", addressBasedAccessControl);
        mockGraphRule1 = new MockGraphRule();
        mockGraphRule2 = new MockGraphRule();
        mockFollowRule1 = new MockFollowRule();
        mockFollowRule2 = new MockFollowRule();
        vm.stopPrank();
    }

    // Test initialization
    function testInitialization() public {
        assertEq(graph.getMetadataURI(), "test-graph");
        assertEq(address(graph.getAccessControl()), address(addressBasedAccessControl));
    }

    // Test access control
    function testSetAccessControl() public {
        vm.prank(owner);
        graph.setAccessControl(ownerOnlyAccessControl);
        assertEq(address(graph.getAccessControl()), address(ownerOnlyAccessControl));
    }

    function testSetAccessControlUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        graph.setAccessControl(ownerOnlyAccessControl);

        // Verify that the access control was not changed
        assertEq(address(graph.getAccessControl()), address(addressBasedAccessControl));
    }

    // Test metadata URI
    function testSetMetadataURI() public {
        string memory newMetadataURI = "new-metadata-uri";
        vm.prank(adminSetMetadata);
        vm.expectEmit();
        emit Lens_Graph_MetadataURISet(newMetadataURI);
        graph.setMetadataURI(newMetadataURI);
        assertEq(graph.getMetadataURI(), newMetadataURI);
    }

    function testCannotSetMetadataURIWithoutPermission() public {
        vm.prank(user1);
        vm.expectRevert();
        graph.setMetadataURI("new-metadata-uri");
    }

    // Test set extra data
    function testSetExtraData() public {
        bytes32 key1 = keccak256("key1");
        bytes32 key2 = keccak256("key2");
        bytes memory value1 = abi.encode("value1");
        bytes memory value2 = abi.encode(42);

        DataElement[] memory extraDataToSet = new DataElement[](2);
        extraDataToSet[0] = DataElement(key1, value1);
        extraDataToSet[1] = DataElement(key2, value2);

        vm.prank(addminSetExtraData);
        vm.expectEmit();
        emit Lens_Graph_ExtraDataSet(key1, value1, value1);
        emit Lens_Graph_ExtraDataSet(key2, value2, value2);
        graph.setExtraData(extraDataToSet);

        assertEq(graph.getExtraData(key1), value1);
        assertEq(graph.getExtraData(key2), value2);
    }

    function testCannotSetExtraDataUnauthorized() public {
        bytes32 key = keccak256("key");
        bytes memory value = abi.encode("value");

        DataElement[] memory extraDataToSet = new DataElement[](1);
        extraDataToSet[0] = DataElement(key, value);

        vm.prank(user1);
        vm.expectRevert(); // Expect the transaction to revert due to lack of permission
        graph.setExtraData(extraDataToSet);

        // Verify that the data was not set
        assertEq(graph.getExtraData(key), "");
    }

    // Test add graph rules
    function testAddGraphRules() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.prank(adminSetRules);
        vm.expectEmit();
        emit Lens_Graph_RuleAdded(address(mockGraphRule1), abi.encode("config"), true);
        graph.addGraphRules(rules);

        address[] memory addedRules = graph.getGraphRules(true);
        assertEq(addedRules.length, 1);
        assertEq(addedRules[0], address(mockGraphRule1));
    }

    function testCannotAddGraphRulesWithoutPermission() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.prank(user1);
        vm.expectRevert();
        graph.addGraphRules(rules);
    }

    function testCannotAddGraphRulesConfigurationFailed() public {
        // Set mockGraphRule1 to fail configuration
        MockGraphRule(address(mockGraphRule1)).setConfigurationWillFail(true);

        // Try to add graph rules (should fail due to configuration failure)
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.prank(adminSetRules);
        vm.expectRevert("AddRule: Rule configuration failed");
        graph.addGraphRules(rules);

        // Verify no rules were added
        address[] memory addedRules = graph.getGraphRules(true);
        assertEq(addedRules.length, 0);
    }

    function testCannotAddExistingGraphRule() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.startPrank(adminSetRules);
        graph.addGraphRules(rules);

        vm.expectRevert("AddRule: Same rule was already added");
        graph.addGraphRules(rules);
    }

    // Test update graph rules
    function testUpdateGraphRulesConfig() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.startPrank(adminSetRules);
        graph.addGraphRules(rules);

        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("new-config"), true);
        vm.expectEmit();
        emit Lens_Graph_RuleUpdated(address(mockGraphRule1), abi.encode("new-config"), true);
        graph.updateGraphRules(rules);
        vm.stopPrank();

        // check that config was updated
        string memory newConfig = mockGraphRule1.lastConfig();
        assertEq(newConfig, "new-config");
    }

    function testUpdateGraphRulesFromRequiredToAnyOf() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true); // isRequired = true

        vm.startPrank(adminSetRules);
        graph.addGraphRules(rules);

        // Verify the rule is in the required rules
        address[] memory requiredRules = graph.getGraphRules(true);
        assertEq(requiredRules.length, 1);
        assertEq(requiredRules[0], address(mockGraphRule1));

        // Update the rule to be any-of
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("new-config"), false); // isRequired = false
        graph.updateGraphRules(rules);

        // Verify the rule is now in the any-of rules
        address[] memory anyOfRules = graph.getGraphRules(false);
        assertEq(anyOfRules.length, 1);
        assertEq(anyOfRules[0], address(mockGraphRule1));

        // Verify it's no longer in the required rules
        requiredRules = graph.getGraphRules(true);
        assertEq(requiredRules.length, 0);

        vm.stopPrank();
    }

    function testUpdateGraphRulesFromAnyOfToRequired() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), false); // isRequired = false

        vm.startPrank(adminSetRules);
        graph.addGraphRules(rules);

        // Verify the rule is in the any-of rules
        address[] memory anyOfRules = graph.getGraphRules(false);
        assertEq(anyOfRules.length, 1);
        assertEq(anyOfRules[0], address(mockGraphRule1));

        // Update the rule to be required
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("new-config"), true); // isRequired = true
        graph.updateGraphRules(rules);

        // Verify the rule is now in the required rules
        address[] memory requiredRules = graph.getGraphRules(true);
        assertEq(requiredRules.length, 1);
        assertEq(requiredRules[0], address(mockGraphRule1));

        // Verify it's no longer in the any-of rules
        anyOfRules = graph.getGraphRules(false);
        assertEq(anyOfRules.length, 0);

        vm.stopPrank();
    }

    function testCannotUpdateGraphRulesWithoutPermission() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);
        vm.startPrank(adminSetRules);
        graph.addGraphRules(rules);
        vm.stopPrank();

        vm.prank(user1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("new-config"), true);
        vm.expectRevert();
        graph.updateGraphRules(rules);
    }

    function testCannotUpdateGraphRulesConfigurationFailed() public {
        // Add initial graph rules
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        // Set mockGraphRule1 to fail configuration
        MockGraphRule(address(mockGraphRule1)).setConfigurationWillFail(true);

        // Try to update graph rules (should fail due to configuration failure)
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("new-config"), true);

        vm.prank(adminSetRules);
        vm.expectRevert("AddRule: Rule configuration failed");
        graph.updateGraphRules(rules);
    }

    function testCannotUpdateNonExistingGraphRules() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.prank(adminSetRules);
        vm.expectRevert("ConfigureRule: Rule doesn't exist");
        graph.updateGraphRules(rules);
    }

    // Test remove graph rules
    function testRemoveGraphRules() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.startPrank(adminSetRules);
        graph.addGraphRules(rules);

        address[] memory rulesToRemove = new address[](1);
        rulesToRemove[0] = address(mockGraphRule1);
        vm.expectEmit();
        emit Lens_Graph_RuleRemoved(address(mockGraphRule1));
        graph.removeGraphRules(rulesToRemove);
        vm.stopPrank();

        address[] memory remainingRules = graph.getGraphRules(true);
        assertEq(remainingRules.length, 0);
    }

    function testCannotRemoveGraphRulesWithoutPermission() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.startPrank(adminSetRules);
        graph.addGraphRules(rules);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert();
        address[] memory rulesToRemove = new address[](1);
        rulesToRemove[0] = address(mockGraphRule1);
        graph.removeGraphRules(rulesToRemove);
    }

    function testCannotRemoveGraphRulesNotSet() public {
        vm.prank(adminSetRules);
        vm.expectRevert("RuleNotSet");
        address[] memory rulesToRemove = new address[](1);
        rulesToRemove[0] = address(mockGraphRule1);
        graph.removeGraphRules(rulesToRemove);
    }

    // Test add follow rules
    function testAddFollowRules() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config"), true);

        vm.prank(user1);
        RuleExecutionData memory graphRulesData;
        vm.expectEmit();
        emit Lens_Graph_Follow_RuleAdded(user1, address(mockFollowRule1), rules[0]);
        graph.addFollowRules(user1, rules, graphRulesData);

        address[] memory addedRules = graph.getFollowRules(user1, true);
        assertEq(addedRules.length, 1);
        assertEq(addedRules[0], address(mockFollowRule1));
    }

    function testAddFollowRulesWithProcessFollowRulesChange() public {
        // Setup graph rules
        RuleConfiguration[] memory graphRules = new RuleConfiguration[](1);
        graphRules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.startPrank(adminSetRules);
        graph.addGraphRules(graphRules);
        mockGraphRule1.setRequireWhitelisted(true);
        mockGraphRule1.setWhitelistedRule(address(mockFollowRule1), true);
        vm.stopPrank();

        // Test adding whitelisted follow rule
        RuleConfiguration[] memory followRules = new RuleConfiguration[](1);
        followRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config"), true);

        vm.prank(user1);
        graph.addFollowRules(user1, followRules, RuleExecutionData(new bytes[](1), new bytes[](0)));

        // Verify rule was added
        address[] memory addedRules = graph.getFollowRules(user1, true);
        assertEq(addedRules.length, 1);
        assertEq(addedRules[0], address(mockFollowRule1));

        // Test adding non-whitelisted follow rule (should fail)
        followRules[0] = RuleConfiguration(address(mockFollowRule2), abi.encode("config"), true);

        vm.prank(user1);
        vm.expectRevert("Some required rule failed");
        graph.addFollowRules(user1, followRules, RuleExecutionData(new bytes[](1), new bytes[](0)));
    }

    function testAddFollowRulesWithMultipleRequiredGraphRules() public {
        // Setup graph rules
        RuleConfiguration[] memory graphRules = new RuleConfiguration[](2);
        graphRules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), true);
        graphRules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), true);

        vm.prank(adminSetRules);
        graph.addGraphRules(graphRules);
        mockGraphRule1.setRequireWhitelisted(true);
        mockGraphRule2.setRequireWhitelisted(true);
        mockGraphRule1.setWhitelistedRule(address(mockFollowRule1), true);
        mockGraphRule2.setWhitelistedRule(address(mockFollowRule1), true);
        vm.stopPrank();

        // Test adding follow rules (should succeed if both required rules pass)
        RuleConfiguration[] memory followRules = new RuleConfiguration[](1);
        followRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config"), true);

        vm.prank(user1);
        graph.addFollowRules(user1, followRules, RuleExecutionData(new bytes[](2), new bytes[](0)));

        // Verify rule was added
        address[] memory addedRules = graph.getFollowRules(user1, true);
        assertEq(addedRules.length, 1);
        assertEq(addedRules[0], address(mockFollowRule1));
    }

    function testAddFollowRulesWithAnyOfGraphRules() public {
        // Setup graph rules
        RuleConfiguration[] memory graphRules = new RuleConfiguration[](3);
        graphRules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), false);
        graphRules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), false);

        vm.prank(adminSetRules);
        graph.addGraphRules(graphRules);
        mockGraphRule1.setRequireWhitelisted(true);
        mockGraphRule2.setRequireWhitelisted(true);
        mockGraphRule1.setWhitelistedRule(address(mockFollowRule1), false); // first rule isn't passed
        mockGraphRule2.setWhitelistedRule(address(mockFollowRule1), true);

        // Test adding follow rules (should succeed if at least one any-of rule passes)
        RuleConfiguration[] memory followRules = new RuleConfiguration[](1);
        followRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config"), true);

        vm.prank(user1);
        graph.addFollowRules(user1, followRules, RuleExecutionData(new bytes[](0), new bytes[](2)));

        // Verify rule was added
        address[] memory addedRules = graph.getFollowRules(user1, true);
        assertEq(addedRules.length, 1);
        assertEq(addedRules[0], address(mockFollowRule1));
    }

    function testCannotAddFollowRulesForOtherAccount() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config"), true);

        vm.prank(user2);
        vm.expectRevert();
        RuleExecutionData memory graphRulesData;
        graph.addFollowRules(user1, rules, graphRulesData);
    }

    function testCannotAddExistingFollowRule() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config"), true);

        vm.startPrank(user1);
        RuleExecutionData memory graphRulesData;
        graph.addFollowRules(user1, rules, graphRulesData);

        vm.expectRevert("AddRule: Same rule was already added");
        graph.addFollowRules(user1, rules, graphRulesData);
    }

    function testCannotAddFollowRulesConfigurationFailed() public {
        // Set mockFollowRule1 to fail configuration
        MockFollowRule(address(mockFollowRule1)).setConfigurationWillFail(true);

        // Try to add follow rules (should fail due to configuration failure)
        RuleConfiguration[] memory followRules = new RuleConfiguration[](1);
        followRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config"), true);

        vm.prank(user1);
        vm.expectRevert("AddRule: Rule configuration failed");
        graph.addFollowRules(user1, followRules, RuleExecutionData(new bytes[](1), new bytes[](0)));

        // Verify no rules were added
        address[] memory addedRules = graph.getFollowRules(user1, true);
        assertEq(addedRules.length, 0);
    }

    // Test update follow rules
    function testUpdateFollowRules() public {
        // Setup initial follow rules
        RuleConfiguration[] memory initialRules = new RuleConfiguration[](2);
        initialRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), true);
        initialRules[1] = RuleConfiguration(address(mockFollowRule2), abi.encode("config2"), false);

        vm.startPrank(user1);
        graph.addFollowRules(user1, initialRules, RuleExecutionData(new bytes[](0), new bytes[](0)));

        // Update follow rules
        RuleConfiguration[] memory updatedRules = new RuleConfiguration[](2);
        updatedRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("new-config1"), true);
        updatedRules[1] = RuleConfiguration(address(mockFollowRule2), abi.encode("new-config2"), true);

        vm.expectEmit();
        emit Lens_Graph_Follow_RuleUpdated(user1, address(mockFollowRule1), updatedRules[0]);
        emit Lens_Graph_Follow_RuleUpdated(user1, address(mockFollowRule2), updatedRules[1]);
        graph.updateFollowRules(user1, updatedRules, RuleExecutionData(new bytes[](0), new bytes[](0)));
        vm.stopPrank();

        // Verify rules were updated
        address[] memory requiredRules = graph.getFollowRules(user1, true);
        address[] memory anyOfRules = graph.getFollowRules(user1, false);

        assertEq(requiredRules.length, 2);
        assertEq(requiredRules[0], address(mockFollowRule1));
        assertEq(requiredRules[1], address(mockFollowRule2));
        assertEq(anyOfRules.length, 0);

        assertEq(mockFollowRule1.lastConfig(), "new-config1");
        assertEq(mockFollowRule2.lastConfig(), "new-config2");
    }

    function testCannotUpdateFollowRulesOfOtherAccount() public {
        // Setup initial follow rules
        RuleConfiguration[] memory initialRules = new RuleConfiguration[](1);
        initialRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), true);

        vm.prank(user1);
        graph.addFollowRules(user1, initialRules, RuleExecutionData(new bytes[](0), new bytes[](0)));

        // Attempt to update follow rules of other account
        RuleConfiguration[] memory updatedRules = new RuleConfiguration[](1);
        updatedRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("new-config"), true);

        vm.prank(user2);
        vm.expectRevert();
        graph.updateFollowRules(user1, updatedRules, RuleExecutionData(new bytes[](0), new bytes[](0)));
    }

    function testCannotUpdateNonExistingFollowRules() public {
        // Attempt to update follow rules that were never set
        RuleConfiguration[] memory updatedRules = new RuleConfiguration[](1);
        updatedRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("new-config"), true);

        vm.prank(user1);
        vm.expectRevert("ConfigureRule: Rule doesn't exist");
        graph.updateFollowRules(user1, updatedRules, RuleExecutionData(new bytes[](0), new bytes[](0)));
    }

    function testCannotUpdateFollowRulesConfigurationFailed() public {
        // Add initial follow rules
        RuleConfiguration[] memory initialRules = new RuleConfiguration[](1);
        initialRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), true);

        vm.prank(user1);
        graph.addFollowRules(user1, initialRules, RuleExecutionData(new bytes[](1), new bytes[](0)));

        // Set mockFollowRule2 to fail configuration
        MockFollowRule(address(mockFollowRule1)).setConfigurationWillFail(true);

        // Try to update follow rules (should fail due to configuration failure)
        RuleConfiguration[] memory updatedRules = new RuleConfiguration[](1);
        updatedRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("new-config1"), true);

        vm.prank(user1);
        vm.expectRevert("AddRule: Rule configuration failed");
        graph.updateFollowRules(user1, updatedRules, RuleExecutionData(new bytes[](1), new bytes[](0)));
    }

    function testCannotUpdateFollowRulesWithGraphRuleRestrictions() public {
        // Setup graph rules with restrictions
        RuleConfiguration[] memory graphRules = new RuleConfiguration[](1);
        graphRules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("graph-config"), true);

        vm.prank(adminSetRules);
        graph.addGraphRules(graphRules);

        // Setup initial follow rules
        RuleConfiguration[] memory initialRules = new RuleConfiguration[](1);
        initialRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), true);

        vm.prank(user1);
        graph.addFollowRules(user1, initialRules, RuleExecutionData(new bytes[](1), new bytes[](0)));

        // Attempt to update follow rules (should fail due to graph rule restrictions)
        RuleConfiguration[] memory updatedRules = new RuleConfiguration[](1);
        updatedRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("new-config"), true);

        // Disallow rule changes in mockGraphRule
        vm.prank(adminSetRules);
        mockGraphRule1.setAllowRuleChanges(false);

        // User cannot update follow rules
        vm.prank(user1);
        vm.expectRevert("Some required rule failed");
        graph.updateFollowRules(user1, updatedRules, RuleExecutionData(new bytes[](1), new bytes[](0)));

        // Verify original rules are still in place
        address[] memory requiredRules = graph.getFollowRules(user1, true);
        assertEq(requiredRules.length, 1);
        assertEq(requiredRules[0], address(mockFollowRule1));
    }

    // Test remove follow rules
    function testRemoveFollowRules() public {
        // Setup initial follow rules
        RuleConfiguration[] memory initialRules = new RuleConfiguration[](2);
        initialRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), true);
        initialRules[1] = RuleConfiguration(address(mockFollowRule2), abi.encode("config2"), false);

        vm.startPrank(user1);
        graph.addFollowRules(user1, initialRules, RuleExecutionData(new bytes[](0), new bytes[](0)));

        // Remove follow rules
        address[] memory rulesToRemove = new address[](2);
        rulesToRemove[0] = address(mockFollowRule1);
        rulesToRemove[1] = address(mockFollowRule2);
        vm.expectEmit();
        emit Lens_Graph_Follow_RuleRemoved(user1, address(mockFollowRule1));
        emit Lens_Graph_Follow_RuleRemoved(user1, address(mockFollowRule2));
        graph.removeFollowRules(user1, rulesToRemove, RuleExecutionData(new bytes[](0), new bytes[](0)));

        // Verify rules were removed
        address[] memory requiredRules = graph.getFollowRules(user1, true);
        address[] memory anyOfRules = graph.getFollowRules(user1, false);

        assertEq(requiredRules.length, 0);
        assertEq(anyOfRules.length, 0);
    }

    function testCannotRemoveFollowRulesOfOtherAccount() public {
        // Setup initial follow rules
        RuleConfiguration[] memory initialRules = new RuleConfiguration[](1);
        initialRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), true);

        vm.prank(user1);
        graph.addFollowRules(user1, initialRules, RuleExecutionData(new bytes[](0), new bytes[](0)));

        // Attempt to remove follow rules of other account
        address[] memory rulesToRemove = new address[](1);
        rulesToRemove[0] = address(mockFollowRule1);

        vm.prank(user2);
        vm.expectRevert();
        graph.removeFollowRules(user1, rulesToRemove, RuleExecutionData(new bytes[](0), new bytes[](0)));
    }

    function testCannotRemoveNotSetFollowRules() public {
        // Attempt to remove follow rules that were never set
        address[] memory rulesToRemove = new address[](1);
        rulesToRemove[0] = address(mockFollowRule1);

        vm.prank(user1);
        vm.expectRevert("RuleNotSet");
        graph.removeFollowRules(user1, rulesToRemove, RuleExecutionData(new bytes[](0), new bytes[](0)));
    }

    function testCannotRemoveFollowRulesWithGraphRuleRestrictions() public {
        // Setup graph rules with restrictions
        RuleConfiguration[] memory graphRules = new RuleConfiguration[](1);
        graphRules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("graph-config"), true);

        vm.prank(adminSetRules);
        graph.addGraphRules(graphRules);

        // Setup initial follow rules
        RuleConfiguration[] memory initialRules = new RuleConfiguration[](1);
        initialRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), true);

        vm.prank(user1);
        graph.addFollowRules(user1, initialRules, RuleExecutionData(new bytes[](1), new bytes[](0)));

        // Attempt to remove follow rules (should fail due to graph rule restrictions)
        address[] memory rulesToRemove = new address[](1);
        rulesToRemove[0] = address(mockFollowRule1);

        // Disallow rule changes in mockGraphRule
        vm.prank(adminSetRules);
        mockGraphRule1.setAllowRuleChanges(false);

        // User cannot remove follow rules
        vm.prank(user1);
        vm.expectRevert("Some required rule failed");
        graph.removeFollowRules(user1, rulesToRemove, RuleExecutionData(new bytes[](1), new bytes[](0)));

        // Verify original rules are still in place
        address[] memory requiredRules = graph.getFollowRules(user1, true);
        assertEq(requiredRules.length, 1);
        assertEq(requiredRules[0], address(mockFollowRule1));
    }

    // Test follow
    function testFollow() public {
        vm.prank(user1);
        RuleExecutionData memory graphRulesData;
        RuleExecutionData memory followRulesData;

        vm.expectEmit();
        emit Lens_Graph_Followed(user1, user2, 1, graphRulesData, followRulesData);
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
        assertEq(graph.getFollowerById(user2, followId), user1);

        Follow memory follow = graph.getFollow(user1, user2);
        assertEq(follow.id, followId);
        assertEq(follow.timestamp, block.timestamp);
    }

    function testFollowWithSpecificId() public {
        uint256 specificId = 5;
        vm.startPrank(user1);
        RuleExecutionData memory graphRulesData;
        RuleExecutionData memory followRulesData;
        uint256 followId;

        // Increment followId by 1 each time
        for (uint256 i = 0; i < specificId + 1; i++) {
            followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);
            graph.unfollow(user1, user2, graphRulesData);
        }

        followId = graph.follow(user1, user2, specificId, graphRulesData, followRulesData);

        assertEq(followId, specificId);
        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
        assertEq(graph.getFollowerById(user2, followId), user1);
    }

    function testFollowWithBothGraphAndFollowRules() public {
        // Add graph rules
        RuleConfiguration[] memory graphRules = new RuleConfiguration[](1);
        graphRules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("graphConfig"), true);

        vm.prank(adminSetRules);
        graph.addGraphRules(graphRules);

        // Add follow rules for user2
        RuleConfiguration[] memory followRules = new RuleConfiguration[](1);
        followRules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("followConfig"), true);

        vm.prank(user2);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        graph.addFollowRules(user2, followRules, graphRulesData);

        // Follow
        vm.prank(user1);
        RuleExecutionData memory followRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
        assertEq(graph.getFollowerById(user2, followId), user1);

        // Check if both graph and follow rules were processed
        assertEq(mockGraphRule1.lastFollowerAccount(), user1);
        assertEq(mockGraphRule1.lastAccountToFollow(), user2);

        assertEq(mockFollowRule1.lastFollowerAccount(), user1);
        assertEq(mockFollowRule1.lastAccountToFollow(), user2);
    }

    function testFollowWithMultipleRequiredRulesAllPass() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), true);
        rules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), true);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        vm.prank(user1);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](2), new bytes[](0));
        RuleExecutionData memory followRulesData;
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
        assertEq(graph.getFollowerById(user2, followId), user1);
    }

    function testFollowWithMultipleAnyOfRulesAllPass() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), false);
        rules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), false);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        vm.prank(user1);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](0), new bytes[](2));
        RuleExecutionData memory followRulesData;
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
        assertEq(graph.getFollowerById(user2, followId), user1);
    }

    function testFollowWithMultipleAnyOfRulesOnePassesOneFails() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), false);
        rules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), false);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        mockGraphRule2.setShouldPass(false); // Second rule will fail

        vm.prank(user1);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](0), new bytes[](2));
        RuleExecutionData memory followRulesData;
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
        assertEq(graph.getFollowerById(user2, followId), user1);
    }

    function testFollowWithFollowRules() public {
        // Add a follow rule for user2
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config"), true);

        vm.prank(user2);
        RuleExecutionData memory graphRulesData;
        graph.addFollowRules(user2, rules, graphRulesData);

        // Follow
        vm.prank(user1);
        RuleExecutionData memory followRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        // Check if the follow rule was processed
        assertEq(mockFollowRule1.lastFollowerAccount(), user1);
        assertEq(mockFollowRule1.lastAccountToFollow(), user2);
        assertEq(followId, 1);
    }

    function testFollowWithMultipleRequiredFollowRulesAllPass() public {
        // Add follow rules for user2
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), true);
        rules[1] = RuleConfiguration(address(mockFollowRule2), abi.encode("config2"), true);

        vm.prank(user2);
        RuleExecutionData memory graphRulesData;
        graph.addFollowRules(user2, rules, graphRulesData);

        // Follow
        vm.prank(user1);
        RuleExecutionData memory followRulesData = RuleExecutionData(new bytes[](2), new bytes[](0));
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
        assertEq(graph.getFollowerById(user2, followId), user1);
    }

    function testFollowWithMultipleAnyOfFollowRulesOnePassesOneFails() public {
        // Add follow rules for user2
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), false);
        rules[1] = RuleConfiguration(address(mockFollowRule2), abi.encode("config2"), false);

        vm.prank(user2);
        RuleExecutionData memory graphRulesData;
        graph.addFollowRules(user2, rules, graphRulesData);

        mockFollowRule1.setShouldPass(false); // First rule will fail

        // Follow
        vm.prank(user1);
        RuleExecutionData memory followRulesData = RuleExecutionData(new bytes[](0), new bytes[](2));
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
        assertEq(graph.getFollowerById(user2, followId), user1);
    }

    function testCannotFollowUsingOtherAccount() public {
        vm.startPrank(user1);
        RuleExecutionData memory graphRulesData;
        RuleExecutionData memory followRulesData;
        vm.expectRevert();
        graph.follow(user2, user1, 0, graphRulesData, followRulesData);
    }

    function testCannotFollowTwice() public {
        vm.startPrank(user1);
        RuleExecutionData memory graphRulesData;
        RuleExecutionData memory followRulesData;
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        // Transaction reverted because user1 is already following user2
        vm.expectRevert();
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);
        vm.stopPrank();

        // User2 should have only 1 follower
        assertEq(graph.getFollowersCount(user2), 1);
    }

    function testCannotFollowSelf() public {
        vm.prank(user1);
        RuleExecutionData memory graphRulesData;
        RuleExecutionData memory followRulesData;

        vm.expectRevert();
        graph.follow(user1, user1, 0, graphRulesData, followRulesData);
    }

    function testCannotFollowWithIdMoreThanLastIdAssigned() public {
        uint256 specificId = 42;

        vm.prank(user1);
        RuleExecutionData memory graphRulesData;
        RuleExecutionData memory followRulesData;
        // Follow ID more than lastFollowIdAssigned
        vm.expectRevert();
        graph.follow(user1, user2, specificId, graphRulesData, followRulesData);
    }

    function testCannotFollowWithTakenId() public {
        vm.prank(user1);
        RuleExecutionData memory graphRulesData;
        RuleExecutionData memory followRulesData;
        // Increase the current followId of user3 to 1
        uint256 followId = graph.follow(user1, user3, 0, graphRulesData, followRulesData);
        assertEq(followId, 1);

        // Transaction reverted because followId is already taken
        vm.prank(user2);
        vm.expectRevert();
        graph.follow(user2, user3, 1, graphRulesData, followRulesData);
    }

    function testCannotFollowWithMultipleRequiredRulesOneFails() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), true);
        rules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), true);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        mockGraphRule1.setShouldPass(false);

        vm.prank(user1);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](2), new bytes[](0));
        RuleExecutionData memory followRulesData;
        vm.expectRevert("Some required rule failed");
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertFalse(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 0);
    }

    function testCannotFollowWithMultipleRequiredFollowRulesOneFails() public {
        // Add follow rules for user2
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), true);
        rules[1] = RuleConfiguration(address(mockFollowRule2), abi.encode("config2"), true);

        vm.prank(user2);
        RuleExecutionData memory graphRulesData;
        graph.addFollowRules(user2, rules, graphRulesData);

        mockFollowRule2.setShouldPass(false);

        // Try to follow
        vm.prank(user1);
        RuleExecutionData memory followRulesData = RuleExecutionData(new bytes[](2), new bytes[](0));
        vm.expectRevert("Some required rule failed");
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertFalse(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 0);
    }

    function testCannotFollowWithMultipleAnyOfRulesAllFail() public {
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), false);
        rules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), false);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        mockGraphRule1.setShouldPass(false);
        mockGraphRule2.setShouldPass(false);

        vm.prank(user1);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](0), new bytes[](2));
        RuleExecutionData memory followRulesData;
        vm.expectRevert("All of the any-of rules failed");
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertFalse(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 0);
    }

    function testCannotFollowWithMultipleAnyOfFollowRulesAllFail() public {
        // Add follow rules for user2
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockFollowRule1), abi.encode("config1"), false);
        rules[1] = RuleConfiguration(address(mockFollowRule2), abi.encode("config2"), false);

        vm.prank(user2);
        RuleExecutionData memory graphRulesData;
        graph.addFollowRules(user2, rules, graphRulesData);

        mockFollowRule1.setShouldPass(false);
        mockFollowRule2.setShouldPass(false);

        // Try to follow
        vm.prank(user1);
        RuleExecutionData memory followRulesData = RuleExecutionData(new bytes[](0), new bytes[](2));
        vm.expectRevert("All of the any-of rules failed");
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        assertFalse(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 0);
    }

    // Test unfollow
    function testUnfollow() public {
        // First, follow
        vm.startPrank(user1);
        RuleExecutionData memory graphRulesData;
        RuleExecutionData memory followRulesData;
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        // Then, unfollow
        vm.expectEmit();
        emit Lens_Graph_Unfollowed(user1, user2, followId, graphRulesData);
        uint256 unfollowedId = graph.unfollow(user1, user2, graphRulesData);
        vm.stopPrank();

        assertFalse(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 0);
        assertEq(unfollowedId, followId);
        Follow memory follow = graph.getFollow(user1, user2);
        assertEq(follow.id, 0);
        assertEq(follow.timestamp, 0);
        assertEq(graph.getFollowerById(user2, followId), address(0));
    }

    function testUnfollowWithGraphRules() public {
        // Add a graph rule
        RuleConfiguration[] memory rules = new RuleConfiguration[](1);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config"), true);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        // Follow and then unfollow
        vm.startPrank(user1);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](1), new bytes[](0));
        RuleExecutionData memory followRulesData;
        uint256 followId = graph.follow(user1, user2, 0, graphRulesData, followRulesData);
        uint256 unfollowedId = graph.unfollow(user1, user2, graphRulesData);
        vm.stopPrank();

        // Check if the graph rule was processed for unfollow
        assertEq(mockGraphRule1.lastUnfollowerAccount(), user1);
        assertEq(mockGraphRule1.lastAccountToUnfollow(), user2);
        assertEq(mockGraphRule1.lastFollowId(), unfollowedId);
        assertEq(followId, unfollowedId);
    }

    function testUnfollowWithMultipleRequiredRulesAllPass() public {
        // First, follow
        vm.prank(user1);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](2), new bytes[](0));
        RuleExecutionData memory followRulesData;
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        // Add rules
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), true);
        rules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), true);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        // Unfollow
        vm.prank(user1);
        graph.unfollow(user1, user2, graphRulesData);

        assertFalse(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 0);
    }

    function testUnfollowWithMultipleAnyOfRulesOnePassesOneFails() public {
        // First, follow
        vm.prank(user1);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](0), new bytes[](2));
        RuleExecutionData memory followRulesData;
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        // Add rules
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), false);
        rules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), false);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        mockGraphRule1.setShouldPass(false);

        // Unfollow
        vm.prank(user1);
        graph.unfollow(user1, user2, graphRulesData);

        assertFalse(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 0);
    }

    function testCannotUnfollowIfNotFollowing() public {
        vm.prank(user1);
        RuleExecutionData memory graphRulesData;

        vm.expectRevert();
        graph.unfollow(user1, user2, graphRulesData);
    }

    function testCannotUnfollowUsingOtherAccount() public {
        vm.prank(user1);
        RuleExecutionData memory graphRulesData;
        RuleExecutionData memory followRulesData;
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        vm.prank(user3);
        vm.expectRevert();
        graph.unfollow(user1, user2, graphRulesData);
    }

    function testCannotUnfollowWithMultipleRequiredRulesOneFails() public {
        // First, follow
        vm.prank(user1);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](2), new bytes[](0));
        RuleExecutionData memory followRulesData;
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        // Add rules
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), true);
        rules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), true);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        mockGraphRule2.setShouldPass(false);

        // Try to unfollow
        vm.prank(user1);
        vm.expectRevert("Some required rule failed");
        graph.unfollow(user1, user2, graphRulesData);

        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
    }

    function testCannotUnfollowWithMultipleAnyOfRulesAllFail() public {
        // First, follow
        vm.prank(user1);
        RuleExecutionData memory graphRulesData = RuleExecutionData(new bytes[](0), new bytes[](2));
        RuleExecutionData memory followRulesData;
        graph.follow(user1, user2, 0, graphRulesData, followRulesData);

        // Add rules
        RuleConfiguration[] memory rules = new RuleConfiguration[](2);
        rules[0] = RuleConfiguration(address(mockGraphRule1), abi.encode("config1"), false);
        rules[1] = RuleConfiguration(address(mockGraphRule2), abi.encode("config2"), false);

        vm.prank(adminSetRules);
        graph.addGraphRules(rules);

        mockGraphRule1.setShouldPass(false);
        mockGraphRule2.setShouldPass(false);

        // Try to unfollow
        vm.prank(user1);
        vm.expectRevert("All of the any-of rules failed");
        graph.unfollow(user1, user2, graphRulesData);

        assertTrue(graph.isFollowing(user1, user2));
        assertEq(graph.getFollowersCount(user2), 1);
    }
}
