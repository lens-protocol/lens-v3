// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Beacon} from "@core/upgradeability/Beacon.sol";
import {Errors} from "@core/types/Errors.sol";

contract BeaconTest is Test {
    Beacon beacon;
    uint256 DEFAULT_INIT_VERSION = 1;
    address DEFAULT_OWNER = address(this);
    address DEFAULT_IMPL = address(0xc0ffee);

    function setUp() public virtual {
        beacon = new Beacon({owner: DEFAULT_OWNER, version: DEFAULT_INIT_VERSION, initialImplementation: DEFAULT_IMPL});
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_Constructor_SetsProperValues(address owner, uint256 version, address implementation) public {
        vm.assume(implementation != address(0));

        beacon = new Beacon({owner: owner, version: version, initialImplementation: implementation});

        assertEq(beacon.implementation(), implementation);
        assertEq(beacon.implementation(version), implementation);
        assertEq(beacon.owner(), owner);
    }

    function test_Constructor_CannotSet_InitialImplAsZeroAddress(address owner, uint256 version) public {
        vm.expectRevert(Errors.InvalidParameter.selector);
        new Beacon({owner: owner, version: version, initialImplementation: address(0)});
    }

    function test_Cannot_SetImplementation_IfNotOwner(address nonOwner, uint256 version, address implementation)
        public
    {
        vm.assume(implementation != address(0));
        vm.assume(nonOwner != beacon.owner());

        vm.prank(nonOwner);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        beacon.setImplementationForVersion({version: version, implementationToSet: implementation});
    }

    function test_Cannot_SetDefaultVersion_IfNotOwner(address nonOwner, uint256 version, address implementation)
        public
    {
        vm.assume(implementation != address(0));
        vm.assume(nonOwner != beacon.owner());

        beacon.setImplementationForVersion({version: version, implementationToSet: implementation});

        vm.prank(nonOwner);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        beacon.setDefaultVersion({version: version});
    }

    function test_Cannot_SetImplementation_IfNullifyingDefaultImplementation() public {
        vm.expectRevert(Errors.InvalidParameter.selector);
        beacon.setImplementationForVersion({version: DEFAULT_INIT_VERSION, implementationToSet: address(0)});
    }

    function test_SetImplementation_ToNullIfNotDefaultImplementation(uint256 nonDefaultVersion) public {
        vm.assume(nonDefaultVersion != DEFAULT_INIT_VERSION);

        beacon.setImplementationForVersion({version: nonDefaultVersion, implementationToSet: DEFAULT_IMPL});
        assertEq(beacon.implementation(nonDefaultVersion), DEFAULT_IMPL);

        beacon.setImplementationForVersion({version: nonDefaultVersion, implementationToSet: address(0)});

        vm.expectRevert(Errors.InvalidParameter.selector);
        assertEq(beacon.implementation(nonDefaultVersion), address(0));
    }

    function test_Cannot_GetImplementationForNullifiedVersion(uint256 version) public {
        vm.assume(version != DEFAULT_INIT_VERSION);

        vm.expectRevert(Errors.InvalidParameter.selector);
        beacon.implementation(version);
    }

    function test_GetImplementation_AfterSettingANewDefaultVersion(uint256 newDefaultVersion, address newImplementation)
        public
    {
        vm.assume(newDefaultVersion != DEFAULT_INIT_VERSION);
        vm.assume(newImplementation != address(0));

        assertEq(beacon.implementation(), DEFAULT_IMPL);
        assertEq(beacon.implementation(DEFAULT_INIT_VERSION), DEFAULT_IMPL);

        beacon.setImplementationForVersion({version: newDefaultVersion, implementationToSet: newImplementation});

        assertEq(beacon.implementation(), DEFAULT_IMPL);
        assertEq(beacon.implementation(DEFAULT_INIT_VERSION), DEFAULT_IMPL);
        assertEq(beacon.implementation(newDefaultVersion), newImplementation);

        beacon.setDefaultVersion({version: newDefaultVersion});

        assertEq(beacon.implementation(), newImplementation);
        assertEq(beacon.implementation(DEFAULT_INIT_VERSION), DEFAULT_IMPL);
        assertEq(beacon.implementation(newDefaultVersion), newImplementation);
    }

    function test_Cannot_TransferOwnership_IfNotOwner(address nonOwner, address newOwner) public {
        vm.assume(nonOwner != beacon.owner());

        vm.prank(nonOwner);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        beacon.transferOwnership({newOwner: newOwner});
    }

    function test_TransferOwnership_IfOwner(address newOwner) public {
        beacon.transferOwnership({newOwner: newOwner});
        assertEq(beacon.owner(), newOwner);

        vm.prank(newOwner);
        beacon.transferOwnership({newOwner: address(this)});
        assertEq(beacon.owner(), address(this));
    }

    function test_Cannot_SetDefaultVersion_IfImplIsZeroAddress(uint256 version) public {
        vm.assume(version != DEFAULT_INIT_VERSION);

        vm.expectRevert(Errors.InvalidParameter.selector);
        beacon.setDefaultVersion(version);
    }
}
