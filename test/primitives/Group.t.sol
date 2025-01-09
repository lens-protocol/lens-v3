// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {IGroup} from "@core/interfaces/IGroup.sol";
import {Group, PID__ADD_MEMBER, PID__REMOVE_MEMBER} from "@core/primitives/group/Group.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {AccessControlled} from "@core/access/AccessControlled.sol";
import {Errors} from "@core/types/Errors.sol";

contract GroupTest is Test, BaseDeployments {
    IGroup group;

    address account = makeAddr("ACCOUNT");
    address groupOwner = makeAddr("GROUP_OWNER");
    MockAccessControl mockAccessControl;

    function setUp() public override {
        super.setUp();

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

        vm.prank(groupOwner);
        AccessControlled(address(group)).setAccessControl(IAccessControl(address(mockAccessControl)));

        mockAccessControl.mockAccess(groupOwner, address(group), PID__ADD_MEMBER, true);
        mockAccessControl.mockAccess(groupOwner, address(group), PID__REMOVE_MEMBER, true);
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

    function testCannot_AddMember_viaPID_noAccess(address newMember) public {
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

    event Lens_Group_MemberRemoved(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    function test_removeMember_viaPID(address memberToRemove) public {
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

    function testCannot_removeMember_viaPID_noAccess(address memberToRemove) public {
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

    // TODO: Additional test cases to implement:
    /*
    Membership Addition Validations:
    - testCannot_AddMember_AlreadyMember
    - testCannot_JoinGroup_AlreadyMember
    - testCannot_AddMember_ZeroAddress
    - testCannot_JoinGroup_ZeroAddress
    - testCannot_JoinGroup_DifferentSender (when msg.sender != account param)

    Membership Removal Validations:
    - testCannot_RemoveMember_NotMember
    - testCannot_LeaveGroup_NotMember
    - testCannot_RemoveMember_ZeroAddress
    - testCannot_LeaveGroup_ZeroAddress
    - testCannot_LeaveGroup_DifferentSender (when msg.sender != account param)

    Membership Status Checks:
    - test_GetMembershipId_Success
    - testCannot_GetMembershipId_NotMember
    - test_GetMembershipTimestamp_Success
    - testCannot_GetMembershipTimestamp_NotMember
    - test_GetMembership_Success
    - testCannot_GetMembership_NotMember

    Member Count Validations:
    - test_NumberOfMembers_IncreasesOnAdd
    - test_NumberOfMembers_DecreasesOnRemove
    - test_NumberOfMembers_IncreasesOnJoin
    - test_NumberOfMembers_DecreasesOnLeave
    */
}
