// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Community} from "contracts/primitives/community/Community.sol";
import {CommunityCore} from "contracts/primitives/community/CommunityCore.sol";
import {IAccessControl} from "contracts/primitives/access-control/IAccessControl.sol";
import {ICommunityRule} from "contracts/primitives/community/ICommunityRule.sol";
import {CommunityRuleCombinator} from "contracts/primitives/community/CommunityRuleCombinator.sol";

contract CommunityTest is Test {
    Community public community;
    address public owner = makeAddr("OWNER");
    address public alice = makeAddr("ALICE");
    address public bob = makeAddr("BOB");

    string public initialMetadataURI = "ipfs://initial-metadata-uri";
    address public accessControlAddress = makeAddr("ACCESS_CONTROL");

    // Declare the constants within the test contract
    uint256 constant SET_RULES_RID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_RID = uint256(keccak256("SET_METADATA"));
    uint256 constant CHANGE_ACCESS_CONTROL_RID = uint256(keccak256("CHANGE_ACCESS_CONTROL"));

    // Declare the required events
    event Lens_Community_MetadataUriSet(string metadataURI);
    event Lens_Community_RulesSet(address communityRules);
    event Lens_Community_MemberJoined(address account, uint256 memberId, bytes data);
    event Lens_Community_MemberLeft(address account, uint256 memberId, bytes data);
    event Lens_Community_MemberRemoved(address account, uint256 memberId, bytes data);

    function setUp() public {
        // Deploy the Community contract with initial metadata URI and access control contract
        IAccessControl accessControl = IAccessControl(accessControlAddress);
        community = new Community(initialMetadataURI, accessControl);
    }

    function testSetCommunityRules() public {
        CommunityRuleCombinator communityRules = new CommunityRuleCombinator();

        // Mock access control to allow setting the rules
        vm.mockCall(
            accessControlAddress,
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, owner, address(community), SET_RULES_RID),
            abi.encode(true)
        );
        
        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_Community_RulesSet(address(communityRules));

        // Call the function that triggers the event
        vm.prank(owner);
        community.setCommunityRules(ICommunityRule(address(communityRules)));

        // Assert that the community rules were updated
        assertEq(community.getCommunityRules(), address(communityRules), "Community rules should be updated");
    }


    function testSetMetadataURI() public {
        string memory newMetadataURI = "ipfs://new-metadata-uri";

        // Mock access control to allow setting the metadata URI
        vm.mockCall(
            accessControlAddress,
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, owner, address(community), SET_METADATA_RID),
            abi.encode(true)
        );

        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit Lens_Community_MetadataUriSet(newMetadataURI);

        vm.prank(owner);
        community.setMetadataURI(newMetadataURI);

        // Assert the metadata URI is updated
        assertEq(community.getMetadataURI(), newMetadataURI, "Metadata URI should be updated");
    }

    function testSetAccessControl() public {
        address newAccessControl = makeAddr("NEW_ACCESS_CONTROL");

        // Mock access control to allow changing the access control contract
        vm.mockCall(
            accessControlAddress,
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, owner, address(community), CHANGE_ACCESS_CONTROL_RID),
            abi.encode(true)
        );

        // Mock the new access control to return true when calling hasAccess with default parameters
        vm.mockCall(
            newAccessControl,
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, address(0), address(0), 0),
            abi.encode(true)
        );

        // Call setAccessControl with the new access control contract
        vm.prank(owner);
        community.setAccessControl(IAccessControl(newAccessControl));

        // Assert that access control was updated
        assertEq(community.getAccessControl(), newAccessControl, "Access control should be updated");
    }

    function testJoinCommunity() public {
        bytes memory joinData = "JOIN_DATA";

        // Expect the member joined event
        vm.expectEmit(true, true, true, true);
        emit Lens_Community_MemberJoined(alice, 1, joinData);

        vm.prank(alice);
        community.joinCommunity(alice, joinData);

        // Assert that membership was granted
        assertEq(community.getMembershipId(alice), 1, "Membership ID should be 1");
        assertEq(community.getNumberOfMembers(), 1, "Number of members should be 1");
    }

    function testLeaveCommunity() public {
        bytes memory leaveData = "LEAVE_DATA";

        // First, add Alice to the community
        vm.prank(alice);
        community.joinCommunity(alice, "");

        // Expect the member left event
        vm.expectEmit(true, true, true, true);
        emit Lens_Community_MemberLeft(alice, 1, leaveData);

        // Alice leaves the community
        vm.prank(alice);
        community.leaveCommunity(alice, leaveData);

        // Assert that membership was revoked
        assertEq(community.getMembershipId(alice), 0, "Membership ID should be 0");
        assertEq(community.getNumberOfMembers(), 0, "Number of members should be 0");
    }

    function testRemoveMember() public {
        bytes memory removeData = "REMOVE_DATA";

        CommunityRuleCombinator communityRules = new CommunityRuleCombinator();

        // First, add Alice to the community
        vm.prank(alice);
        community.joinCommunity(alice, "");

        // Mock access control to grant permission to set rules
        vm.mockCall(
            accessControlAddress,
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, owner, address(community), SET_RULES_RID),
            abi.encode(true)
        );

        // Mock the community rules processRemoval to prevent reverting
        vm.mockCall(
            address(communityRules),
            abi.encodeWithSelector(ICommunityRule.processRemoval.selector, owner, alice, removeData),
            ""
        );

        // Set the community rules
        vm.prank(owner);
        community.setCommunityRules(ICommunityRule(address(communityRules)));

        // Expect the member removed event
        vm.expectEmit(true, true, true, true);
        emit Lens_Community_MemberRemoved(alice, 1, removeData);

        // Remove Alice from the community
        vm.prank(owner);
        community.removeMember(alice, removeData);

        // Assert that Alice was removed
        assertEq(community.getMembershipId(alice), 0, "Membership ID should be 0 after removal");
        assertEq(community.getNumberOfMembers(), 0, "Number of members should be 0 after removal");
    }

    function testRevokeMembership() public {
        bytes memory removeData = "REMOVE_DATA";

        // First, add Alice to the community
        vm.prank(alice);
        community.joinCommunity(alice, "");

        // Expect the member removed event
        vm.expectEmit(true, true, true, true);
        emit Lens_Community_MemberLeft(alice, 1, removeData);

        // Revoke Alice's membership
        vm.prank(alice);
        community.leaveCommunity(alice, removeData);

        // Assert that Alice's membership was revoked
        assertEq(community.getMembershipId(alice), 0, "Membership ID should be 0");
        assertEq(community.getNumberOfMembers(), 0, "Number of members should be 0");
    }
}
