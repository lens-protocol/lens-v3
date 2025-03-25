// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IGroup} from "@core/interfaces/IGroup.sol";
import {Group} from "@core/primitives/group/Group.sol";
import "test/helpers/TypeHelpers.sol";
import {Errors} from "@core/types/Errors.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {BanMemberGroupRule} from "@rules/group/BanMemberGroupRule.sol";

contract BanMemberGroupRuleTest is BaseDeployments {
    IGroup group;

    address groupOwner = makeAddr("GROUP_OWNER");

    function setUp() public override {
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
        vm.label(address(group), "OUR_GROUP");
    }

    function test_canBan_NonMember(address accountToBan) public {
        vm.assume(accountToBan != address(0));
        vm.assume(group.isMember(accountToBan) == false);

        vm.prank(groupOwner);
        BanMemberGroupRule(banMemberGroupRule).ban(
            address(group), accountToBan, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray()
        );

        assertEq(BanMemberGroupRule(banMemberGroupRule).isMemberBanned(address(group), accountToBan), true);

        vm.expectRevert(Errors.RequiredRuleReverted.selector);
        vm.prank(accountToBan);
        group.joinGroup(accountToBan, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray());
    }

    function test_canBan_Member(address accountToBan) public {
        vm.assume(accountToBan != address(0));
        vm.assume(group.isMember(accountToBan) == false);

        vm.prank(accountToBan);
        group.joinGroup(accountToBan, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray());

        assertEq(group.isMember(accountToBan), true);

        vm.prank(groupOwner);
        BanMemberGroupRule(banMemberGroupRule).ban(
            address(group), accountToBan, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray()
        );

        assertEq(group.isMember(accountToBan), false);
        assertEq(BanMemberGroupRule(banMemberGroupRule).isMemberBanned(address(group), accountToBan), true);

        vm.expectRevert(Errors.RequiredRuleReverted.selector);
        vm.prank(accountToBan);
        group.joinGroup(accountToBan, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray());
    }

    function test_canUnban(address accountToUnban) public {
        vm.assume(accountToUnban != address(0));
        vm.assume(group.isMember(accountToUnban) == false);

        vm.prank(groupOwner);
        BanMemberGroupRule(banMemberGroupRule).ban(
            address(group), accountToUnban, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray()
        );

        assertEq(BanMemberGroupRule(banMemberGroupRule).isMemberBanned(address(group), accountToUnban), true);

        vm.expectRevert(Errors.RequiredRuleReverted.selector);
        vm.prank(accountToUnban);
        group.joinGroup(accountToUnban, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray());

        vm.prank(groupOwner);
        BanMemberGroupRule(banMemberGroupRule).unban(address(group), accountToUnban);

        assertEq(BanMemberGroupRule(banMemberGroupRule).isMemberBanned(address(group), accountToUnban), false);

        vm.prank(accountToUnban);
        group.joinGroup(accountToUnban, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray());

        assertEq(group.isMember(accountToUnban), true);
    }
}
