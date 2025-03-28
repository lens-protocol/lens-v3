// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "test/helpers/TypeHelpers.sol";
import {AccessControlled} from "@core/access/AccessControlled.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {Errors} from "@core/types/Errors.sol";
import {Group, PID__ADD_MEMBER, PID__REMOVE_MEMBER} from "@core/primitives/group/Group.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {IAccountGroupAdditionSettings} from "@core/interfaces/IAccountGroupAdditionSettings.sol";
import {IGroup, Membership} from "@core/interfaces/IGroup.sol";
import {IGroupRule} from "@core/interfaces/IGroupRule.sol";
import {IMetadataBased} from "@core/interfaces/IMetadataBased.sol";
import {Lock} from "@core/upgradeability/Lock.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {Rule, KeyValue, RuleConfigurationChange} from "@core/types/Types.sol";
import {RuleExecutionTest} from "test/primitives/rules/RuleExecution.t.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";

contract GroupTest is RulesTest, BaseDeployments, RuleExecutionTest {
    IGroup group;
    IGroup factoryDeployedGroup;
    address account = makeAddr("ACCOUNT");
    address groupOwner = makeAddr("GROUP_OWNER");
    MockAccessControl mockAccessControl;
    address groupForRules;

    function setUp() public override(RulesTest, BaseDeployments, RuleExecutionTest) {
        BaseDeployments.setUp();

        group = IGroup(
            lensFactory.deployGroup({
                metadataURI: "some metadata uri",
                owner: groupOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray(),
                foundingMember: address(0)
            })
        );

        factoryDeployedGroup = IGroup(
            lensFactory.deployGroup({
                metadataURI: "some metadata uri",
                owner: groupOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray(),
                foundingMember: address(0)
            })
        );

        mockAccessControl = new MockAccessControl();

        vm.prank(address(lensFactory));
        groupForRules = groupFactory.deployGroup({
            metadataURI: "uri://group",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray(),
            foundingMember: address(0)
        });

        address groupAccessControl = address(AccessControlled(address(group)).getAccessControl());
        vm.prank(accessControlLockOwner);
        Lock(accessControlLock).setLockStatusForAddress(groupAccessControl, false);

        vm.prank(groupOwner);
        AccessControlled(address(group)).setAccessControl(IAccessControl(address(mockAccessControl)));

        mockAccessControl.mockAccess(groupOwner, address(group), PID__ADD_MEMBER, true);
        mockAccessControl.mockAccess(groupOwner, address(group), PID__REMOVE_MEMBER, true);

        RulesTest.setUp();

        RuleExecutionTest.setUp();
    }

    event Lens_Group_MemberAdded(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    // TODO: Move these to a PID Helper or something
    function _getAccountWithPID(uint256 PID) internal returns (address) {
        address accountWithPID = makeAddr(string.concat("PID_HOLDER_", vm.toString(PID)));
        mockAccessControl.mockAccess(accountWithPID, address(group), PID, true);
        vm.assertTrue(mockAccessControl.hasAccess(accountWithPID, address(group), PID));
        return accountWithPID;
    }

    function _getAccountWithoutPID(uint256 PID) internal returns (address) {
        address accountWithoutPID = makeAddr(string.concat("PID_HOLDER_", vm.toString(PID)));
        mockAccessControl.mockAccess(accountWithoutPID, address(group), PID, false);
        vm.assertFalse(mockAccessControl.hasAccess(accountWithoutPID, address(group), PID));
        return accountWithoutPID;
    }

    function test_AddMember_LensFactoryConfiguration_MsgSenderIsOwner(address newMember) public {
        vm.assume(newMember != address(0));
        vm.assume(newMember != address(vm));

        vm.assume(factoryDeployedGroup.isMember(newMember) == false);

        uint256 expectedMembershipId = group.getNumberOfMembers() + 1;

        vm.mockCall(
            newMember,
            abi.encodeWithSelector(
                IAccountGroupAdditionSettings.canBeAddedToGroup.selector,
                address(group),
                groupOwner,
                _emptyKeyValueArray()
            ),
            abi.encode(true)
        );

        vm.expectEmit(true, true, true, true);
        emit Lens_Group_MemberAdded(
            newMember, expectedMembershipId, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray(), address(0)
        );

        vm.prank(groupOwner);
        group.addMember({
            account: newMember,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertTrue(group.isMember(newMember));
    }

    function test_AddMember_LensFactoryConfiguration_MsgSenderWithoutAddMemberPID(address msgSender, address newMember)
        public
    {
        vm.assume(newMember != address(0));
        vm.assume(newMember != address(vm));

        vm.assume(
            AccessControlled(address(factoryDeployedGroup)).getAccessControl().hasAccess(
                msgSender, address(factoryDeployedGroup), PID__ADD_MEMBER
            ) == false
        );

        vm.assume(factoryDeployedGroup.isMember(newMember) == false);

        vm.mockCall(
            newMember,
            abi.encodeWithSelector(
                IAccountGroupAdditionSettings.canBeAddedToGroup.selector,
                address(group),
                msgSender,
                _emptyKeyValueArray()
            ),
            abi.encode(true)
        );

        vm.prank(msgSender);
        vm.expectRevert(Errors.RequiredRuleReverted.selector);
        factoryDeployedGroup.addMember({
            account: newMember,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertFalse(group.isMember(newMember));
    }

    function _disableAllRulesFromGroupSelector(address groupAddress, bytes4 selector, address msgSender) internal {
        Rule[] memory requiredRules = IGroup(groupAddress).getGroupRules(selector, true);
        Rule[] memory anyOfRules = IGroup(groupAddress).getGroupRules(selector, false);
        RuleChange[] memory ruleChanges = new RuleChange[](requiredRules.length + anyOfRules.length);

        RuleConfigurationChange memory noRuleConfigChanges =
            RuleConfigurationChange({configure: false, ruleParams: _emptyKeyValueArray()});

        RuleSelectorChange[] memory disableSelectorForRequired = new RuleSelectorChange[](1);
        disableSelectorForRequired[0] = RuleSelectorChange({ruleSelector: selector, isRequired: true, enabled: false});
        for (uint256 i = 0; i < requiredRules.length; i++) {
            ruleChanges[i] = RuleChange({
                ruleAddress: requiredRules[i].ruleAddress,
                configSalt: requiredRules[i].configSalt,
                configurationChanges: noRuleConfigChanges,
                selectorChanges: disableSelectorForRequired
            });
        }

        RuleSelectorChange[] memory disableSelectorForAnyOf = new RuleSelectorChange[](1);
        disableSelectorForAnyOf[0] = RuleSelectorChange({ruleSelector: selector, isRequired: false, enabled: false});
        for (uint256 i = 0; i < anyOfRules.length; i++) {
            ruleChanges[i + requiredRules.length] = RuleChange({
                ruleAddress: requiredRules[i].ruleAddress,
                configSalt: requiredRules[i].configSalt,
                configurationChanges: noRuleConfigChanges,
                selectorChanges: disableSelectorForAnyOf
            });
        }

        vm.prank(msgSender);
        IGroup(groupAddress).changeGroupRules(ruleChanges);
    }

    function test_AddMember_PermissionlessIfNoProcessAdditionRules(address msgSender, address newMember) public {
        vm.assume(newMember != address(0));
        vm.assume(newMember != address(vm));

        mockAccessControl.mockAccess(groupOwner, address(group), PID__CHANGE_RULES, true);
        _disableAllRulesFromGroupSelector(address(group), IGroupRule.processAddition.selector, groupOwner);

        assertEq(group.getGroupRules(IGroupRule.processAddition.selector, true).length, 0);
        assertEq(group.getGroupRules(IGroupRule.processAddition.selector, false).length, 0);

        vm.assume(group.isMember(newMember) == false);

        uint256 expectedMembershipId = group.getNumberOfMembers() + 1;

        vm.mockCall(
            newMember,
            abi.encodeWithSelector(
                IAccountGroupAdditionSettings.canBeAddedToGroup.selector,
                address(group),
                msgSender,
                _emptyKeyValueArray()
            ),
            abi.encode(true)
        );

        vm.expectEmit(true, true, true, true);
        emit Lens_Group_MemberAdded(
            newMember, expectedMembershipId, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray(), address(0)
        );

        vm.prank(msgSender);
        group.addMember({
            account: newMember,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertTrue(group.isMember(newMember));
    }

    function test_RemoveMember_PermissionlessIfNoProcessRemovalRules(address msgSender, address memberToRemove) public {
        vm.assume(memberToRemove != address(0));
        vm.assume(memberToRemove != address(vm));

        _forceMemberIntoGroup(memberToRemove);
        vm.assume(group.isMember(memberToRemove) == true);

        mockAccessControl.mockAccess(groupOwner, address(group), PID__CHANGE_RULES, true);
        _disableAllRulesFromGroupSelector(address(group), IGroupRule.processRemoval.selector, groupOwner);

        assertEq(group.getGroupRules(IGroupRule.processRemoval.selector, true).length, 0);
        assertEq(group.getGroupRules(IGroupRule.processRemoval.selector, false).length, 0);

        vm.prank(msgSender);
        group.removeMember({
            account: memberToRemove,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        vm.assume(group.isMember(memberToRemove) == false);
    }

    // TODO: Add this to GroupHelpers or something
    function _forceMemberIntoGroup(address member) internal {
        vm.assume(member != address(vm)); // skip vm contract
        if (group.isMember(member) == false) {
            vm.mockCall(
                member,
                abi.encodeWithSelector(
                    IAccountGroupAdditionSettings.canBeAddedToGroup.selector,
                    address(group),
                    groupOwner,
                    _emptyKeyValueArray()
                ),
                abi.encode(true)
            );
            vm.prank(groupOwner);
            group.addMember({
                account: member,
                customParams: _emptyKeyValueArray(),
                ruleProcessingParams: _emptyRuleProcessingParamsArray()
            });
        }
        assertTrue(group.isMember(member));
    }

    // TODO: Add this to GroupHelpers or something
    function _setGroupNotMember(address member) internal {
        if (group.isMember(member)) {
            vm.prank(groupOwner);
            group.removeMember({
                account: member,
                customParams: _emptyKeyValueArray(),
                ruleProcessingParams: _emptyRuleProcessingParamsArray()
            });
        }
        assertFalse(group.isMember(member));
    }

    event Lens_Group_MemberRemoved(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    function test_RemoveMember_LensFactoryConfiguration_MsgSenderIsOwner(address memberToRemove) public {
        vm.assume(memberToRemove != address(0));

        _forceMemberIntoGroup(memberToRemove);
        uint256 expectedMembershipId = group.getMembershipId(memberToRemove);

        vm.expectEmit(true, true, true, true);
        emit Lens_Group_MemberRemoved(
            memberToRemove, expectedMembershipId, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray(), address(0)
        );

        vm.prank(groupOwner);
        group.removeMember({
            account: memberToRemove,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertFalse(group.isMember(memberToRemove));
    }

    event Lens_Group_MemberJoined(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    function test_joinGroup(address newMember) public {
        vm.assume(newMember != address(0));
        vm.assume(group.isMember(newMember) == false);

        uint256 expectedMembershipId = group.getNumberOfMembers() + 1;

        vm.expectEmit(true, true, true, true);
        emit Lens_Group_MemberJoined(
            newMember, expectedMembershipId, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray(), address(0)
        );

        vm.prank(newMember);
        group.joinGroup({
            account: newMember,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertTrue(group.isMember(newMember));
    }

    event Lens_Group_MemberLeft(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    function test_leaveGroup(address memberToLeave) public {
        vm.assume(memberToLeave != address(0));

        _forceMemberIntoGroup(memberToLeave);

        uint256 expectedMembershipId = group.getMembershipId(memberToLeave);

        vm.expectEmit(true, true, true, true);
        emit Lens_Group_MemberLeft(
            memberToLeave, expectedMembershipId, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray(), address(0)
        );

        vm.prank(memberToLeave);
        group.leaveGroup({
            account: memberToLeave,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertFalse(group.isMember(memberToLeave));
    }

    function test_CannotAddMemberIf_AlreadyMember(address member) public {
        vm.assume(member != address(0));

        // First add the member
        _forceMemberIntoGroup(member);

        // Try to add the same member again
        vm.prank(groupOwner);
        vm.expectRevert(Errors.RedundantStateChange.selector);
        group.addMember({
            account: member,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotJoinGroupIf_AlreadyMember(address member) public {
        vm.assume(member != address(0));

        // First add the member
        _forceMemberIntoGroup(member);

        // Try to join the group again
        vm.prank(member);
        vm.expectRevert(Errors.RedundantStateChange.selector);
        group.joinGroup({
            account: member,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotAddMemberIf_ZeroAddress() public {
        vm.prank(groupOwner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        group.addMember({
            account: address(0),
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotJoinGroupIf_ZeroAddress() public {
        vm.prank(groupOwner);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        group.joinGroup({
            account: address(0),
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotJoinGroupIf_DifferentSender(address sender, address differentAccount) public {
        vm.assume(sender != address(0));
        vm.assume(differentAccount != address(0));
        vm.assume(sender != differentAccount);

        vm.prank(sender);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        group.joinGroup({
            account: differentAccount,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotRemoveMemberIf_NotMember(address nonMember) public {
        vm.assume(nonMember != address(0));
        _setGroupNotMember(nonMember);

        vm.prank(groupOwner);
        vm.expectRevert(Errors.RedundantStateChange.selector);
        group.removeMember({
            account: nonMember,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotLeaveGroupIf_NotMember(address nonMember) public {
        vm.assume(nonMember != address(0));
        _setGroupNotMember(nonMember);

        vm.prank(nonMember);
        vm.expectRevert(Errors.RedundantStateChange.selector);
        group.leaveGroup({
            account: nonMember,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotRemoveMemberIf_ZeroAddress() public {
        vm.prank(groupOwner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        group.removeMember({
            account: address(0),
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotLeaveGroupIf_ZeroAddress() public {
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        group.leaveGroup(address(0), new KeyValue[](0), new RuleProcessingParams[](0));
    }

    function test_CannotLeaveGroupIf_DifferentSender(address sender, address differentAccount) public {
        vm.assume(sender != address(0));
        vm.assume(differentAccount != address(0));
        vm.assume(sender != differentAccount);

        // Add the member first
        _forceMemberIntoGroup(differentAccount);

        vm.prank(sender);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        group.leaveGroup({
            account: differentAccount,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_GetMembershipId_Success(address member) public {
        vm.assume(member != address(0));
        uint256 expectedMembershipId = group.getNumberOfMembers() + 1;

        _forceMemberIntoGroup(member);

        uint256 membershipId = group.getMembershipId(member);
        assertTrue(membershipId != 0);
        assertEq(membershipId, expectedMembershipId);
    }

    function test_GetMembershipId_NotMember(address nonMember) public {
        vm.assume(nonMember != address(0));

        vm.expectRevert(Errors.DoesNotExist.selector);
        group.getMembershipId(nonMember);
    }

    function test_GetMembershipTimestamp_Success(address member) public {
        vm.assume(member != address(0));

        uint256 expectedTimestamp = block.timestamp;

        _forceMemberIntoGroup(member);

        uint256 membershipTimestamp = group.getMembershipTimestamp(member);

        // Assert timestamp is after or equal to the timestamp before adding
        assertGe(membershipTimestamp, expectedTimestamp);
    }

    function test_CannotGetMembershipTimestampIf_NotMember(address nonMember) public {
        vm.assume(nonMember != address(0));
        _setGroupNotMember(nonMember);

        vm.expectRevert(Errors.DoesNotExist.selector);
        group.getMembershipTimestamp(nonMember);
    }

    function test_NumberOfMembers_IncreasesOnAdd(uint8 numberOfMembers) public {
        numberOfMembers = uint8(bound(numberOfMembers, 1, 10));
        uint256 startingNumberOfMembers = group.getNumberOfMembers();

        for (uint256 i = 0; i < numberOfMembers; i++) {
            _forceMemberIntoGroup(makeAddr(string.concat("MEMBER_", vm.toString(i))));
            assertEq(group.getNumberOfMembers(), startingNumberOfMembers + i + 1);
        }
    }

    function test_NumberOfMembers_DecreasesOnRemove() public {
        for (uint256 i = 0; i < 10; i++) {
            _forceMemberIntoGroup(makeAddr(string.concat("MEMBER_", vm.toString(i))));
        }

        uint256 startingNumberOfMembers = group.getNumberOfMembers();

        vm.prank(groupOwner);
        group.removeMember({
            account: makeAddr("MEMBER_0"),
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertEq(group.getNumberOfMembers(), startingNumberOfMembers - 1);
    }

    function test_GetMembership_Success(address member) public {
        vm.assume(member != address(0));

        uint256 expectedMembershipId = group.getNumberOfMembers() + 1;
        uint256 expectedTimestamp = block.timestamp;

        _forceMemberIntoGroup(member);

        Membership memory membership = group.getMembership(member);

        assertEq(membership.id, expectedMembershipId);
        assertEq(membership.timestamp, expectedTimestamp);
    }

    function test_CannotGetMembershipIf_NotMember(address nonMember) public {
        vm.assume(nonMember != address(0));
        _setGroupNotMember(nonMember);

        vm.expectRevert(Errors.DoesNotExist.selector);
        group.getMembership(nonMember);
    }

    function test_NumberOfMembers_IncreasesOnJoin() public {
        for (uint256 i = 0; i < 10; i++) {
            _forceMemberIntoGroup(makeAddr(string.concat("MEMBER_", vm.toString(i))));
        }

        uint256 memberCountBefore = group.getNumberOfMembers();

        address member = makeAddr("ANOTHER_MEMBER");

        vm.prank(member);
        group.joinGroup({
            account: member,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        uint256 memberCountAfter = group.getNumberOfMembers();
        assertEq(memberCountAfter, memberCountBefore + 1);
    }

    function test_NumberOfMembers_DecreasesOnLeave() public {
        for (uint256 i = 0; i < 10; i++) {
            _forceMemberIntoGroup(makeAddr(string.concat("MEMBER_", vm.toString(i))));
        }

        uint256 memberCountBefore = group.getNumberOfMembers();

        vm.prank(makeAddr(string.concat("MEMBER_1")));
        group.leaveGroup({
            account: makeAddr(string.concat("MEMBER_1")),
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        uint256 memberCountAfter = group.getNumberOfMembers();
        assertEq(memberCountAfter, memberCountBefore - 1);
    }

    function test_SetMetadataURI_HasPID(address addressWithPID) public {
        string memory newMetadataURI = "uri://new-metadata-uri";
        assertNotEq(IMetadataBased(address(group)).getMetadataURI(), newMetadataURI);
        mockAccessControl.mockAccess(
            addressWithPID, address(group), uint256(keccak256("lens.permission.SetMetadata")), true
        );
        vm.prank(addressWithPID);
        IMetadataBased(address(group)).setMetadataURI(newMetadataURI);
        assertEq(IMetadataBased(address(group)).getMetadataURI(), newMetadataURI);
    }

    function test_Cannot_SetMetadataURI_IfDoesNotHavePID(address addressWithoutPID) public {
        string memory oldMetadataURI = IMetadataBased(address(group)).getMetadataURI();
        string memory newMetadataURI = "uri://new-metadata-uri";
        assertNotEq(oldMetadataURI, newMetadataURI);
        mockAccessControl.mockAccess(
            addressWithoutPID, address(group), uint256(keccak256("lens.permission.SetMetadata")), false
        );
        vm.prank(addressWithoutPID);
        vm.expectRevert(Errors.AccessDenied.selector);
        IMetadataBased(address(group)).setMetadataURI(newMetadataURI);
        assertEq(IMetadataBased(address(group)).getMetadataURI(), oldMetadataURI);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override(RulesTest, RuleExecutionTest) {
        IGroup(groupForRules).changeGroupRules(ruleChanges);
    }

    function _primitiveAddress() internal view override(RulesTest) returns (address) {
        return groupForRules;
    }

    function _aValidRuleSelector() internal pure override(RulesTest) returns (bytes4) {
        return IGroupRule.processAddition.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override(RulesTest) returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IGroupRule.processAddition.selector;
        selectors[1] = IGroupRule.processRemoval.selector;
        selectors[2] = IGroupRule.processJoining.selector;
        selectors[3] = IGroupRule.processLeaving.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required)
        internal
        view
        virtual
        override(RulesTest)
        returns (Rule[] memory)
    {
        return IGroup(groupForRules).getGroupRules(selector, required);
    }

    function _configureRuleSelector() internal pure override(RulesTest, RuleExecutionTest) returns (bytes4) {
        return IGroupRule.configure.selector;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testRuleExecution_JoinGroup(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = IGroupRule.processJoining.selector;
        bytes memory executionFunctionCallData =
            abi.encodeCall(IGroup.joinGroup, (address(this), _emptyKeyValueArray(), _emptyRuleProcessingParamsArray()));
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IGroupRule.processJoining, (bytes32(uint256(1)), address(this), _emptyKeyValueArray(), _emptyKeyValueArray())
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(groupForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_LeaveGroup(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        IGroup(groupForRules).joinGroup(address(this), _emptyKeyValueArray(), _emptyRuleProcessingParamsArray());

        bytes4 executionSelector = IGroupRule.processLeaving.selector;
        bytes memory executionFunctionCallData =
            abi.encodeCall(IGroup.leaveGroup, (address(this), _emptyKeyValueArray(), _emptyRuleProcessingParamsArray()));
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IGroupRule.processLeaving, (bytes32(uint256(1)), address(this), _emptyKeyValueArray(), _emptyKeyValueArray())
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(groupForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_AddMember(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        // If there are group rules on ADD_MEMBER selector then PID__ADD_MEMBER is skipped, giving control to the group rules
        bytes4 executionSelector = IGroupRule.processAddition.selector;
        bytes memory executionFunctionCallData =
            abi.encodeCall(IGroup.addMember, (address(this), _emptyKeyValueArray(), _emptyRuleProcessingParamsArray()));
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IGroupRule.processAddition,
            (bytes32(uint256(1)), address(this), address(this), _emptyKeyValueArray(), _emptyKeyValueArray())
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(groupForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_RemoveMember(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        IGroup(groupForRules).joinGroup(address(this), _emptyKeyValueArray(), _emptyRuleProcessingParamsArray());

        bytes4 executionSelector = IGroupRule.processRemoval.selector;
        bytes memory executionFunctionCallData = abi.encodeCall(
            IGroup.removeMember, (address(this), _emptyKeyValueArray(), _emptyRuleProcessingParamsArray())
        );
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IGroupRule.processRemoval,
            (bytes32(uint256(1)), groupOwner, address(this), _emptyKeyValueArray(), _emptyKeyValueArray())
        );
        mockAccessControl.mockAccess(groupOwner, address(groupForRules), PID__REMOVE_MEMBER, true);
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(groupForRules),
            executionFunctionCallData,
            groupOwner,
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }
}
