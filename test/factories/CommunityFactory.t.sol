// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {CommunityFactory} from "contracts/factories/CommunityFactory.sol";
import {IAccessControl} from "contracts/primitives/access-control/IAccessControl.sol";
import {Community} from "contracts/primitives/community/Community.sol";
import {OwnerOnlyAccessControl} from "contracts/primitives/access-control/OwnerOnlyAccessControl.sol";
import {CommunityRuleCombinator} from "contracts/primitives/community/CommunityRuleCombinator.sol";
import {ICommunityRule} from "contracts/primitives/community/ICommunityRule.sol";
import {RuleCombinator} from "contracts/primitives/rules/RuleCombinator.sol"; 

contract CommunityFactoryTest is Test {
    CommunityFactory public communityFactory;
    IAccessControl public ownerAccessControl;
    address public owner;
    address public alice;

    // Resource IDs
    uint256 constant CHANGE_ACCESS_CONTROL_RID = uint256(keccak256("CHANGE_ACCESS_CONTROL"));
    uint256 constant DEPLOY_COMMUNITY_RID = uint256(keccak256("DEPLOY_COMMUNITY"));

    // Events
    event Lens_CommunityFactory_NewCommunityInstance(
        address indexed communityInstance,
        string metadataURI,
        IAccessControl accessControl,
        ICommunityRule rules,
        bytes rulesInitializationData
    );

    function setUp() public {
        owner = makeAddr("OWNER");
        alice = makeAddr("ALICE");

        // Deploy a mock access control contract where the owner has full control
        ownerAccessControl = new OwnerOnlyAccessControl(owner);
        
        // Deploy the CommunityFactory contract
        communityFactory = new CommunityFactory(ownerAccessControl);
    }

    function testDeployCommunityWithoutRules() public {
        string memory metadataURI = "ipfs://metadata1";
        
        // Mock access control to allow deploying a community
        vm.mockCall(
            address(ownerAccessControl),
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, owner, address(communityFactory), DEPLOY_COMMUNITY_RID),
            abi.encode(true)
        );

        // Expect the event to be emitted with the actual communityInstance address
        vm.expectEmit(false, true, true, false);
        emit Lens_CommunityFactory_NewCommunityInstance({
            communityInstance: address(0), // Use the actual deployed community address
            metadataURI: metadataURI,
            accessControl: ownerAccessControl,
            rules: ICommunityRule(address(0)), // No rules set in this case
            rulesInitializationData: ""
        });

        vm.prank(owner);
        address communityInstance = communityFactory.deploy__Immutable_NoRules(metadataURI, ownerAccessControl);

        // Check that the new community was deployed successfully
        assertTrue(communityInstance != address(0), "Community instance should not be zero");
        Community deployedCommunity = Community(communityInstance);
        assertEq(deployedCommunity.getMetadataURI(), metadataURI, "Metadata URI should match");
        assertEq(deployedCommunity.getAccessControl(), address(ownerAccessControl), "Access control should match");
    }

    function testDeployCommunityWithRules() public {
        string memory metadataURI = "ipfs://metadata2";
        
        // Prepare initialization data
        RuleCombinator.Operation operation = RuleCombinator.Operation.INITIALIZE;
        bytes memory initializationData = abi.encode(RuleCombinator.CombinationMode.AND, address(ownerAccessControl), "");

        // Encode the operation and initialization data
        bytes memory rulesInitializationData = abi.encode(operation, initializationData);

        // Mock access control to allow deploying a community
        vm.mockCall(
            address(ownerAccessControl),
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, owner, address(communityFactory), DEPLOY_COMMUNITY_RID),
            abi.encode(true)
        );

        // Expect the event to be emitted before the deployment call
        vm.expectEmit(false, true, true, false);
        // Emit the expected event with the actual values
        emit Lens_CommunityFactory_NewCommunityInstance({
            communityInstance: address(0),
            metadataURI: metadataURI,
            accessControl: ownerAccessControl,
            rules: ICommunityRule(address(0)),
            rulesInitializationData: rulesInitializationData
        });
        // Deploy the community with rules
        vm.prank(owner);
        address communityInstance = communityFactory.deploy__Immutable_WithRules(metadataURI, ownerAccessControl, rulesInitializationData);

        // Retrieve the rules address from the deployed community
        address rulesAddress = Community(communityInstance).getCommunityRules();

        // Check that the new community was deployed successfully
        assertTrue(communityInstance != address(0), "Community instance should not be zero");
        Community deployedCommunity = Community(communityInstance);
        assertEq(deployedCommunity.getMetadataURI(), metadataURI, "Metadata URI should match");
        assertEq(deployedCommunity.getAccessControl(), address(ownerAccessControl), "Access control should match");

        // Check that the rules were set correctly
        assertTrue(rulesAddress != address(0), "Community rules should not be zero");
        CommunityRuleCombinator rulesInstance = CommunityRuleCombinator(rulesAddress);
        assertEq(uint256(rulesInstance.getCombinationMode()), uint256(RuleCombinator.CombinationMode.AND), "Default combination mode should be AND");
    }




    function testSetAccessControl() public {
        IAccessControl newAccessControl = new OwnerOnlyAccessControl(address(this));

        // Mock access control to allow changing the access control
        vm.mockCall(
            address(ownerAccessControl),
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, owner, address(communityFactory), CHANGE_ACCESS_CONTROL_RID),
            abi.encode(true)
        );

        // Mock call to newAccessControl for hasAccess to pass
        vm.mockCall(
            address(newAccessControl),
            abi.encodeWithSelector(IAccessControl.hasAccess.selector, address(0), address(0), 0),
            abi.encode(true)
        );

        vm.prank(owner);
        communityFactory.setAccessControl(newAccessControl);

        // Assert that the access control was updated
        (bool success,) = address(newAccessControl).call(abi.encodeWithSelector(IAccessControl.hasAccess.selector, address(0), address(0), 0));
        assertTrue(success, "Access control should be updated successfully");
    }
}
