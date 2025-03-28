// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {LensCreate2} from "@core/upgradeability/LensCreate2.sol";
import {ActionHub} from "@extensions/actions/ActionHub.sol";
import {ZkTest} from "test/helpers/ZkTest.sol";

contract LensCreate2Test is ZkTest {
    LensCreate2 create2;
    address IMPLEMENTATION;
    address PROXY_ADMIN;
    bytes INITIALIZER_CALL;
    address EXPECTED_ADDRESS;
    bytes32 SALT;

    function setUp() public virtual onlyZkEvm {
        create2 = new LensCreate2();
        IMPLEMENTATION = address(new ActionHub());
        PROXY_ADMIN = makeAddr("PROXY_ADMIN_1");
        INITIALIZER_CALL = "";
        SALT = keccak256("lens.contract.ActionHub");
        EXPECTED_ADDRESS = create2.getAddress(SALT);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_expectedAddressWithExpectedParams_sameAddress() public {
        address deployedContract = create2.createTransparentUpgradeableProxy({
            salt: SALT,
            implementation: IMPLEMENTATION,
            proxyAdmin: PROXY_ADMIN,
            initializerCall: INITIALIZER_CALL,
            expectedAddress: EXPECTED_ADDRESS
        });
        assertEq(deployedContract, EXPECTED_ADDRESS);
    }

    function test_deployingTwiceFails() public {
        address deployedContract = create2.createTransparentUpgradeableProxy({
            salt: SALT,
            implementation: IMPLEMENTATION,
            proxyAdmin: PROXY_ADMIN,
            initializerCall: INITIALIZER_CALL,
            expectedAddress: EXPECTED_ADDRESS
        });
        assertEq(deployedContract, EXPECTED_ADDRESS);
        vm.expectRevert();
        create2.createTransparentUpgradeableProxy({
            salt: SALT,
            implementation: IMPLEMENTATION,
            proxyAdmin: PROXY_ADMIN,
            initializerCall: INITIALIZER_CALL,
            expectedAddress: EXPECTED_ADDRESS
        });
    }

    function test_diffProxyAdmin_sameAddress(address proxyAdmin) public {
        address deployedContract = create2.createTransparentUpgradeableProxy({
            salt: SALT,
            implementation: IMPLEMENTATION,
            proxyAdmin: proxyAdmin,
            initializerCall: INITIALIZER_CALL,
            expectedAddress: EXPECTED_ADDRESS
        });
        assertEq(deployedContract, EXPECTED_ADDRESS);
    }

    function test_diffImpl_sameAddress() public {
        address deployedContract = create2.createTransparentUpgradeableProxy({
            salt: SALT,
            implementation: address(new ActionHub()),
            proxyAdmin: PROXY_ADMIN,
            initializerCall: INITIALIZER_CALL,
            expectedAddress: EXPECTED_ADDRESS
        });
        assertEq(deployedContract, EXPECTED_ADDRESS);
    }

    function test_diffInitCall_sameAddress() public {
        vm.skip(true); // TODO: Use a diff impl with initializer
        address deployedContract = create2.createTransparentUpgradeableProxy({
            salt: SALT,
            implementation: IMPLEMENTATION,
            proxyAdmin: PROXY_ADMIN,
            initializerCall: INITIALIZER_CALL,
            expectedAddress: EXPECTED_ADDRESS
        });
        assertEq(deployedContract, EXPECTED_ADDRESS);
    }
}
