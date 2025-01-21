// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "@extensions/access/OwnerAdminOnlyAccessControl.sol";
import {IGroup} from "@core/interfaces/IGroup.sol";
import {Group} from "@core/primitives/group/Group.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";

contract GroupTest is Test, BaseDeployments {
    IGroup group;

    address account = makeAddr("ACCOUNT");
    address groupOwner = makeAddr("GROUP_OWNER");

    function setUp() public override {
        super.setUp();

        group = IGroup(
            lensFactory.deployGroup({
                metadataURI: "some metadata uri",
                owner: groupOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray(),
                foundingMember: address(0),
                addFoundingMemberCustomParams: _emptyKeyValueArray()
            })
        );
    }

    function testJoinAndLeave() public {
        vm.prank(account);
        group.joinGroup({
            account: account,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        vm.prank(account);
        group.leaveGroup({
            account: account,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }
}
