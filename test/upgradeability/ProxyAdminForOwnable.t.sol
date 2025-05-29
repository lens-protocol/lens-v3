// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {DependentLock} from "@core/upgradeability/DependentLock.sol";
import {ProxyAdminForOwnable} from "@core/upgradeability/ProxyAdminForOwnable.sol";
import {BeaconProxy} from "@core/upgradeability/BeaconProxy.sol";
import {Errors} from "@core/types/Errors.sol";
import {MockOwnableUniversal} from "test/mocks/MockOwnableUniversal.sol";

contract ProxyAdminForOwnableTest is Test {
    DependentLock lock;
    ProxyAdminForOwnable proxyAdmin;
    MockOwnableUniversal beaconProxy;

    function setUp() public virtual {
        lock = new DependentLock({owner: address(this), locked: true});
        beaconProxy = new MockOwnableUniversal();
        beaconProxy.mockOwner(address(this));
        proxyAdmin = new ProxyAdminForOwnable({lock: address(lock)});
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_Cannot_Call_ChangeProxyAdmin_IfLocked(address admin) public {
        assertTrue(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__changeProxyAdmin.selector, admin);

        vm.expectRevert(Errors.Locked.selector);
        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Cannot_Call_SetBeacon_IfLocked(address beacon) public {
        assertTrue(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__setBeacon.selector, beacon);

        vm.expectRevert(Errors.Locked.selector);
        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Cannot_Call_SetImplementation_IfLocked(address implementation) public {
        assertTrue(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__setImplementation.selector, implementation);

        vm.expectRevert(Errors.Locked.selector);
        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Cannot_Call_TriggerUpgradeToVersion_IfLocked(uint256 version) public {
        assertTrue(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__triggerUpgradeToVersion.selector, version);

        vm.expectRevert(Errors.Locked.selector);
        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Cannot_Call_TriggerUpgrade_IfLocked() public {
        assertTrue(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__triggerUpgrade.selector);

        vm.expectRevert(Errors.Locked.selector);
        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Cannot_Call_OptOutFromAutoUpgrade_IfLocked() public {
        assertTrue(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__optOutFromAutoUpgrade.selector);

        vm.expectRevert(Errors.Locked.selector);
        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Cannot_Call_OptInToAutoUpgrade_IfLocked() public {
        assertTrue(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__optInToAutoUpgrade.selector);

        vm.expectRevert(Errors.Locked.selector);
        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_ChangeProxyAdmin_IfNotLocked(address admin) public {
        lock.setLockStatus(false);
        assertFalse(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__changeProxyAdmin.selector, admin);

        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_SetBeacon_IfNotLocked(address beacon) public {
        lock.setLockStatus(false);
        assertFalse(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__setBeacon.selector, beacon);

        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_SetImplementation_IfNotLocked(address implementation) public {
        lock.setLockStatus(false);
        assertFalse(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__setImplementation.selector, implementation);

        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_TriggerUpgradeToVersion_IfNotLocked(uint256 version) public {
        lock.setLockStatus(false);
        assertFalse(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__triggerUpgradeToVersion.selector, version);

        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_TriggerUpgrade_IfNotLocked() public {
        lock.setLockStatus(false);
        assertFalse(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__triggerUpgrade.selector);

        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_OptOutFromAutoUpgrade_IfNotLocked() public {
        lock.setLockStatus(false);
        assertFalse(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__optOutFromAutoUpgrade.selector);

        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_OptInToAutoUpgrade_IfNotLocked() public {
        lock.setLockStatus(false);
        assertFalse(lock.isLocked(address(beaconProxy)));

        bytes memory data = abi.encodeWithSelector(BeaconProxy.proxy__optInToAutoUpgrade.selector);

        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_OtherSelectors_RegardlessOfLockStatus(bytes4 selector, bool locked) public {
        vm.assume(selector != BeaconProxy.proxy__changeProxyAdmin.selector);
        vm.assume(selector != BeaconProxy.proxy__setBeacon.selector);
        vm.assume(selector != BeaconProxy.proxy__setImplementation.selector);
        vm.assume(selector != BeaconProxy.proxy__triggerUpgradeToVersion.selector);
        vm.assume(selector != BeaconProxy.proxy__triggerUpgrade.selector);
        vm.assume(selector != BeaconProxy.proxy__optOutFromAutoUpgrade.selector);
        vm.assume(selector != BeaconProxy.proxy__optInToAutoUpgrade.selector);

        lock.setLockStatus(locked);

        bytes memory data = abi.encodeWithSelector(selector);

        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_CallingToNonContractFails_BecauseNotOwnable(address eoa, bytes4 selector) public {
        vm.assume(uint160(eoa) > type(uint16).max); // skip system contracts
        vm.assume(eoa.code.length == 0);

        vm.assume(selector != BeaconProxy.proxy__changeProxyAdmin.selector);
        vm.assume(selector != BeaconProxy.proxy__setBeacon.selector);
        vm.assume(selector != BeaconProxy.proxy__setImplementation.selector);
        vm.assume(selector != BeaconProxy.proxy__triggerUpgradeToVersion.selector);
        vm.assume(selector != BeaconProxy.proxy__triggerUpgrade.selector);
        vm.assume(selector != BeaconProxy.proxy__optOutFromAutoUpgrade.selector);
        vm.assume(selector != BeaconProxy.proxy__optInToAutoUpgrade.selector);

        bytes memory data = abi.encodeWithSelector(selector);

        vm.expectRevert();
        proxyAdmin.call(address(eoa), 0, data);
    }

    function test_Call_RevertsWithSameStringMessage_AsTargetContractReverted(bytes4 selector) public {
        lock.setLockStatus(false);

        bytes memory data = abi.encodeWithSelector(selector);

        beaconProxy.mockToRevertOnNextCallWith("Some error message");

        vm.expectRevert("Some error message");
        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_RevertsWithSameErrorSelector_AsTargetContractReverted(bytes4 selector, bytes4 errorSelector)
        public
    {
        lock.setLockStatus(false);

        bytes memory data = abi.encodeWithSelector(selector);

        beaconProxy.mockToRevertOnNextCallWith(errorSelector);

        vm.expectRevert(errorSelector);
        proxyAdmin.call(address(beaconProxy), 0, data);
    }

    function test_Call_RevertsWithoutMessage_IfTargetContractRevertedWithoutMessage(bytes4 selector) public {
        lock.setLockStatus(false);

        bytes memory data = abi.encodeWithSelector(selector);

        beaconProxy.mockToRevertOnNextCall();

        vm.expectRevert();
        proxyAdmin.call(address(beaconProxy), 0, data);
    }
}
