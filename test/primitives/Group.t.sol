// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "@extensions/access/OwnerAdminOnlyAccessControl.sol";
import {IGroup, Membership} from "@core/interfaces/IGroup.sol";
import {Group, PID__ADD_MEMBER, PID__REMOVE_MEMBER} from "@core/primitives/group/Group.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {AccessControlled} from "@core/access/AccessControlled.sol";
import {Errors} from "@core/types/Errors.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";
import {Rule} from "@core/types/Types.sol";
import {IGroupRule} from "@core/interfaces/IGroupRule.sol";

contract GroupTest is RulesTest, BaseDeployments {
    IGroup group;

    address account = makeAddr("ACCOUNT");
    address groupOwner = makeAddr("GROUP_OWNER");
    MockAccessControl mockAccessControl;
    address groupForRules;

    function setUp() public override(RulesTest, BaseDeployments) {
        BaseDeployments.setUp();

        group = IGroup(
            lensFactory.deployGroup({
                metadataURI: "some metadata uri",
                owner: groupOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        mockAccessControl = new MockAccessControl();

        groupForRules = groupFactory.deployGroup({
            metadataURI: "uri://group",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        vm.prank(groupOwner);
        AccessControlled(address(group)).setAccessControl(IAccessControl(address(mockAccessControl)));

        mockAccessControl.mockAccess(groupOwner, address(group), PID__ADD_MEMBER, true);
        mockAccessControl.mockAccess(groupOwner, address(group), PID__REMOVE_MEMBER, true);

        RulesTest.setUp();
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

    function test_AddMember_viaPID(address newMember) public {
        vm.assume(newMember != address(0));

        address accountWithPID = _getAccountWithPID(PID__ADD_MEMBER);

        vm.assume(group.isMember(newMember) == false);

        uint256 expectedMembershipId = group.getNumberOfMembers() + 1;

        vm.expectEmit(true, true, true, true);
        emit Lens_Group_MemberAdded(
            newMember, expectedMembershipId, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray(), address(0)
        );

        vm.prank(accountWithPID);
        group.addMember({
            account: newMember,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertTrue(group.isMember(newMember));
    }

    function test_CannotAddMember_viaPID_noAccess(address newMember) public {
        vm.assume(newMember != address(0));

        address accountWithoutPID = _getAccountWithoutPID(PID__ADD_MEMBER);

        vm.expectRevert(Errors.AccessDenied.selector);
        vm.prank(accountWithoutPID);
        group.addMember({
            account: newMember,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    // TODO: Add this to GroupHelpers or something
    function _setGroupMember(address member) internal {
        if (group.isMember(member) == false) {
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

    function test_removeMember_viaPID(address memberToRemove) public {
        vm.assume(memberToRemove != address(0));

        address accountWithPID = _getAccountWithPID(PID__REMOVE_MEMBER);

        _setGroupMember(memberToRemove);
        uint256 expectedMembershipId = group.getMembershipId(memberToRemove);

        vm.expectEmit(true, true, true, true);
        emit Lens_Group_MemberRemoved(
            memberToRemove, expectedMembershipId, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray(), address(0)
        );

        vm.prank(accountWithPID);
        group.removeMember({
            account: memberToRemove,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertFalse(group.isMember(memberToRemove));
    }

    function test_CannotRemoveMember_viaPID_noAccess(address memberToRemove) public {
        vm.assume(memberToRemove != address(0));

        address accountWithoutPID = _getAccountWithoutPID(PID__REMOVE_MEMBER);

        _setGroupMember(memberToRemove);
        assertTrue(group.isMember(memberToRemove));

        vm.expectRevert(Errors.AccessDenied.selector);
        vm.prank(accountWithoutPID);
        group.removeMember({
            account: memberToRemove,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
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

        _setGroupMember(memberToLeave);

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
        _setGroupMember(member);

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
        _setGroupMember(member);

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
        _setGroupMember(differentAccount);

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

        _setGroupMember(member);

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

        _setGroupMember(member);

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
            _setGroupMember(makeAddr(string.concat("MEMBER_", vm.toString(i))));
            assertEq(group.getNumberOfMembers(), startingNumberOfMembers + i + 1);
        }
    }

    function test_NumberOfMembers_DecreasesOnRemove() public {
        for (uint256 i = 0; i < 10; i++) {
            _setGroupMember(makeAddr(string.concat("MEMBER_", vm.toString(i))));
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

        _setGroupMember(member);

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
            _setGroupMember(makeAddr(string.concat("MEMBER_", vm.toString(i))));
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

    function test_NumberOfMembers_DecreasesOnLeave(address member) public {
        for (uint256 i = 0; i < 10; i++) {
            _setGroupMember(makeAddr(string.concat("MEMBER_", vm.toString(i))));
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

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override {
        IGroup(groupForRules).changeGroupRules(ruleChanges);
    }

    function _primitiveAddress() internal view override returns (address) {
        return groupForRules;
    }

    function _aValidRuleSelector() internal pure override returns (bytes4) {
        return IGroupRule.processAddition.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IGroupRule.processAddition.selector;
        selectors[1] = IGroupRule.processRemoval.selector;
        selectors[2] = IGroupRule.processJoining.selector;
        selectors[3] = IGroupRule.processLeaving.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return IGroup(groupForRules).getGroupRules(selector, required);
    }
}
