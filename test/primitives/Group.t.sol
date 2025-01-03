// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {IAccessControl} from "../../contracts/core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "../../contracts/dashboard/access/OwnerAdminOnlyAccessControl.sol";
import {IGroup} from "../../contracts/core/interfaces/IGroup.sol";
import {Group} from "../../contracts/core/primitives/group/Group.sol";
import "../helpers/TypeHelpers.sol";

contract GroupTest is Test {
    IAccessControl accessControl;
    IGroup group;

    address account = makeAddr("ACCOUNT");

    function setUp() public {
        accessControl = new OwnerAdminOnlyAccessControl(address(this));
        group = new Group({metadataURI: "uri://group-metadata", accessControl: IAccessControl(accessControl)});
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
