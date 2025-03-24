// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {BeaconProxy} from "@core/upgradeability/LegacyBeaconProxy.sol";
import {MockVersionedBeacon} from "test/mocks/MockVersionedBeacon.sol";
import {Errors} from "@core/types/Errors.sol";
import {ZkTest} from "test/helpers/ZkTest.sol";

contract Impl {
    function testImpl() public {
        // Prevents being included in the foundry coverage report
    }

    address immutable IMPL_ADDRESS;

    uint256 internal _storageValue;

    constructor() {
        IMPL_ADDRESS = address(this);
    }

    function returnInteger() public pure returns (uint256) {
        return 69;
    }

    function returnString() public pure returns (string memory) {
        return "gm lens friends!";
    }

    function returnImplAddress() public returns (address) {
        ////// START of the hack to avoid "can be restricted to view" warning.
        uint256 cachedStorageValue = _storageValue;
        delete _storageValue;
        _storageValue = cachedStorageValue;
        ////// END of the hack to avoid "can be restricted to view" warning.
        return IMPL_ADDRESS;
    }

    function revertWithMessage(string memory errorMessage) public pure {
        revert(errorMessage);
    }

    function setStorageValue(uint256 value) public {
        _storageValue = value;
    }

    function getStorageValue() public view returns (uint256) {
        return _storageValue;
    }

    function returnMsgValueReceived() public payable returns (uint256) {
        return msg.value;
    }
}

contract LegacyBeaconProxyTest is ZkTest {
    MockVersionedBeacon beacon;
    BeaconProxy proxy;

    address DEFAULT_PROXY_ADMIN = address(this);
    address DEFAULT_IMPL = address(0xc0ffee);

    function setUp() public virtual {
        beacon = new MockVersionedBeacon();
        beacon.mockImplementation(DEFAULT_IMPL);
        proxy = new BeaconProxy({proxyAdmin: DEFAULT_PROXY_ADMIN, beacon: address(beacon)});
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_Constructor_SetsProperValues() public view {
        assertEq(proxy.proxy__getProxyAdmin(), DEFAULT_PROXY_ADMIN);
        assertEq(proxy.proxy__getBeacon(), address(beacon));
        assertEq(proxy.proxy__getAutoUpgrade(), true);
    }

    function test_Cannot_ChangeProxyAdmin_IfNotProxyAdmin(address nonProxyAdmin) public {
        vm.assume(nonProxyAdmin != proxy.proxy__getProxyAdmin());

        vm.prank(nonProxyAdmin);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        proxy.proxy__changeProxyAdmin(nonProxyAdmin);
    }

    function test_Cannot_OptOutFromAutoUpgrade_IfNotProxyAdmin(address nonProxyAdmin) public {
        vm.assume(nonProxyAdmin != proxy.proxy__getProxyAdmin());

        vm.prank(nonProxyAdmin);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        proxy.proxy__optOutFromAutoUpgrade();
    }

    function test_Cannot_OptInToAutoUpgrade_IfNotProxyAdmin(address nonProxyAdmin) public {
        vm.assume(nonProxyAdmin != proxy.proxy__getProxyAdmin());

        vm.prank(nonProxyAdmin);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        proxy.proxy__optInToAutoUpgrade();
    }

    function test_Cannot_SetImplementation_IfNotProxyAdmin(address nonProxyAdmin, address newImpl) public {
        vm.assume(nonProxyAdmin != proxy.proxy__getProxyAdmin());

        vm.prank(nonProxyAdmin);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        proxy.proxy__setImplementation(newImpl);
    }

    function test_Cannot_SetBeacon_IfNotProxyAdmin(address nonProxyAdmin, address newBeacon) public {
        vm.assume(nonProxyAdmin != proxy.proxy__getProxyAdmin());

        vm.prank(nonProxyAdmin);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        proxy.proxy__setBeacon(newBeacon);
    }

    function test_Cannot_TriggerUpgradeToVersion_IfNotProxyAdmin(address nonProxyAdmin, uint256 version) public {
        vm.assume(nonProxyAdmin != proxy.proxy__getProxyAdmin());

        vm.prank(nonProxyAdmin);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        proxy.proxy__triggerUpgradeToVersion(version);
    }

    function test_Cannot_TriggerUpgrade_IfNotProxyAdmin(address nonProxyAdmin) public {
        vm.assume(nonProxyAdmin != proxy.proxy__getProxyAdmin());

        vm.prank(nonProxyAdmin);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        proxy.proxy__triggerUpgrade();
    }

    function test_Cannot_SetImplementation_IfAutoUpgradesAreEnabled(address newImpl) public {
        assertTrue(proxy.proxy__getAutoUpgrade());

        vm.expectRevert(Errors.AutoUpgradeEnabled.selector);
        proxy.proxy__setImplementation(newImpl);
    }

    function test_ChangeProxyAdmin(address newProxyAdmin) public {
        assertEq(proxy.proxy__getProxyAdmin(), DEFAULT_PROXY_ADMIN);

        proxy.proxy__changeProxyAdmin(newProxyAdmin);
        assertEq(proxy.proxy__getProxyAdmin(), newProxyAdmin);
    }

    function test_OptOutFromAutoUpgrade() public {
        assertTrue(proxy.proxy__getAutoUpgrade());

        proxy.proxy__optOutFromAutoUpgrade();
        assertFalse(proxy.proxy__getAutoUpgrade());
    }

    function test_OptInToAutoUpgrade(address implToFetch) public {
        assertTrue(proxy.proxy__getAutoUpgrade());
        assertEq(proxy.proxy__getImplementation(), DEFAULT_IMPL);

        proxy.proxy__optOutFromAutoUpgrade();
        assertFalse(proxy.proxy__getAutoUpgrade());

        beacon.mockImplementation(implToFetch);

        proxy.proxy__optInToAutoUpgrade();
        assertTrue(proxy.proxy__getAutoUpgrade());
        assertEq(proxy.proxy__getImplementation(), implToFetch);
    }

    function test_SetImplementation(address newImpl) public {
        proxy.proxy__optOutFromAutoUpgrade();
        assertFalse(proxy.proxy__getAutoUpgrade());
        assertEq(proxy.proxy__getImplementation(), DEFAULT_IMPL);

        proxy.proxy__setImplementation(newImpl);
        assertEq(proxy.proxy__getImplementation(), newImpl);
    }

    function test_SetBeacon_AutoUpgradeEnabled(address newBeacon, address newImpl) public {
        vm.assume(newBeacon != address(vm));

        assertEq(proxy.proxy__getBeacon(), address(beacon));
        assertEq(proxy.proxy__getImplementation(), DEFAULT_IMPL);
        assertTrue(proxy.proxy__getAutoUpgrade());

        vm.mockCall(newBeacon, abi.encodeWithSelector(bytes4(keccak256("implementation()"))), abi.encode(newImpl));

        proxy.proxy__setBeacon(newBeacon);
        assertEq(proxy.proxy__getBeacon(), newBeacon);
        assertEq(proxy.proxy__getImplementation(), newImpl);
    }

    function test_SetBeacon_AutoUpgradeDisabled(address newBeacon, address newImpl) public {
        vm.assume(newBeacon != address(vm));

        proxy.proxy__optOutFromAutoUpgrade();
        assertEq(proxy.proxy__getBeacon(), address(beacon));
        assertEq(proxy.proxy__getImplementation(), DEFAULT_IMPL);
        assertFalse(proxy.proxy__getAutoUpgrade());

        vm.mockCall(newBeacon, abi.encodeWithSelector(bytes4(keccak256("implementation()"))), abi.encode(newImpl));

        proxy.proxy__setBeacon(newBeacon);
        assertEq(proxy.proxy__getBeacon(), newBeacon);
        assertEq(proxy.proxy__getImplementation(), DEFAULT_IMPL);

        // Extra test to check triggerUpgrade works after setting a new beacon
        proxy.proxy__triggerUpgrade();
        assertEq(proxy.proxy__getImplementation(), newImpl);
    }

    function test_TriggerUpgrade(address newImpl) public {
        assertEq(proxy.proxy__getImplementation(), DEFAULT_IMPL);
        beacon.mockImplementation(newImpl);

        proxy.proxy__triggerUpgrade();
        assertEq(proxy.proxy__getImplementation(), newImpl);
    }

    function test_TriggerUpgradeToVersion(uint256 version, address newImpl, uint256 anotherVersion, address anotherImpl)
        public
    {
        vm.assume(version != anotherVersion);
        beacon.mockImplementationForVersion(version, newImpl);
        beacon.mockImplementationForVersion(anotherVersion, anotherImpl);
        assertEq(proxy.proxy__getImplementation(), DEFAULT_IMPL);

        proxy.proxy__triggerUpgradeToVersion(version);
        assertEq(proxy.proxy__getImplementation(), newImpl);

        proxy.proxy__triggerUpgradeToVersion(anotherVersion);
        assertEq(proxy.proxy__getImplementation(), anotherImpl);

        proxy.proxy__triggerUpgradeToVersion(version);
        assertEq(proxy.proxy__getImplementation(), newImpl);
    }

    function test_DelegateCall_AutoUpgradeEnabled() public {
        address someImpl = address(new Impl());
        address anotherImpl = address(new Impl());

        beacon.mockImplementation(someImpl);

        assertEq(proxy.proxy__getImplementation(), DEFAULT_IMPL);

        assertEq(Impl(address(proxy)).returnImplAddress(), someImpl);
        assertEq(proxy.proxy__getImplementation(), someImpl);
        assertEq(Impl(address(proxy)).returnInteger(), 69);
        assertEq(Impl(address(proxy)).returnString(), "gm lens friends!");
        assertEq(Impl(address(proxy)).getStorageValue(), 0);
        Impl(address(proxy)).setStorageValue(42);
        assertEq(Impl(address(proxy)).getStorageValue(), 42);
        Impl(address(proxy)).setStorageValue(71);
        assertEq(Impl(address(proxy)).getStorageValue(), 71);
        vm.expectRevert("custom error message");
        Impl(address(proxy)).revertWithMessage("custom error message");

        beacon.mockImplementation(anotherImpl);

        assertEq(Impl(address(proxy)).returnImplAddress(), anotherImpl);
        assertEq(proxy.proxy__getImplementation(), anotherImpl);
        assertEq(Impl(address(proxy)).getStorageValue(), 71);
    }

    function test_DelegateCall_AutoUpgradeDisabled() public {
        address someImpl = address(new Impl());
        address anotherImpl = address(new Impl());

        beacon.mockImplementation(someImpl);

        assertEq(proxy.proxy__getImplementation(), DEFAULT_IMPL);

        assertEq(Impl(address(proxy)).returnImplAddress(), someImpl);
        assertEq(proxy.proxy__getImplementation(), someImpl);
        assertEq(Impl(address(proxy)).returnInteger(), 69);
        assertEq(Impl(address(proxy)).returnString(), "gm lens friends!");
        assertEq(Impl(address(proxy)).getStorageValue(), 0);
        Impl(address(proxy)).setStorageValue(42);
        assertEq(Impl(address(proxy)).getStorageValue(), 42);
        Impl(address(proxy)).setStorageValue(71);
        assertEq(Impl(address(proxy)).getStorageValue(), 71);
        vm.expectRevert("custom error message");
        Impl(address(proxy)).revertWithMessage("custom error message");

        proxy.proxy__optOutFromAutoUpgrade();
        beacon.mockImplementation(anotherImpl);

        assertEq(Impl(address(proxy)).returnImplAddress(), someImpl);
        assertEq(proxy.proxy__getImplementation(), someImpl);

        proxy.proxy__triggerUpgrade();

        assertEq(Impl(address(proxy)).returnImplAddress(), anotherImpl);
        assertEq(proxy.proxy__getImplementation(), anotherImpl);
    }

    function test_CanReceiveNativeToken_UsingTheImpl(uint256 msgValue) public {
        // Bound msgValue [0, 2^95), as test contract's native balance is 2^96, and vm.deal has issues in zksync foundry
        msgValue = msgValue % 1 << 95;
        address someImpl = address(new Impl());
        beacon.mockImplementation(someImpl);
        proxy.proxy__triggerUpgrade();
        assertEq(proxy.proxy__getImplementation(), someImpl);

        assertEq(address(proxy).balance, 0);

        assertEq(Impl(address(proxy)).returnMsgValueReceived{value: msgValue}(), msgValue);

        assertEq(address(proxy).balance, msgValue);
    }

    function test_CanReceiveNativeToken_Directly(uint256 msgValue) public {
        // Bound msgValue [0, 2^95), as test contract's native balance is 2^96, and vm.deal has issues in zksync foundry
        msgValue = msgValue % 1 << 95;

        assertEq(address(proxy).balance, 0);

        (bool callSucceed, bytes memory returnData) = address(proxy).call{value: msgValue}("");

        assertTrue(callSucceed);
        assertEq(returnData.length, 0);
        assertEq(address(proxy).balance, msgValue);
    }

    /**
     * NOTE: This test reproduces the following undesired scenario.
     *
     * The call to Impl::returnInteger is marked as view/pure function, so it is executed as a static call (STATICCALL),
     * expecting no state changes. However, the proxy is doing a state change by executing the auto-upgrade logic and
     * storing the implementation address in its storage.
     */
    function test_DelegateCall_AutoUpgradeDuringGetter_Fails() public onlyEvm {
        address someImpl = address(new Impl());
        beacon.mockImplementation(someImpl);

        vm.expectRevert(); // StateChangeDuringStaticCall
        Impl(address(proxy)).returnInteger();
    }
}
