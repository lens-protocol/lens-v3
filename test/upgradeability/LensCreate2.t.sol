// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {LENS_CREATE_2_ADDRESS, LensCreate2} from "@core/upgradeability/LensCreate2.sol";
import {MockLensCreate2} from "test/mocks/MockLensCreate2.sol";
import {ActionHub} from "@extensions/actions/ActionHub.sol";
import {ZkTest} from "test/helpers/ZkTest.sol";

contract LensCreate2Test is ZkTest {
    LensCreate2 create2;
    address IMPLEMENTATION;
    address PROXY_ADMIN;
    bytes INITIALIZER_CALL;
    address EXPECTED_ADDRESS;
    bytes32 SALT;

    address lensCreate2Owner = makeAddr("LENS_CREATE_2_OWNER");

    address expectedZeroSaltAddress = 0x2753363A2422f6C41501720c65D990d9c0E032D9;

    function setUp() public virtual onlyZkEvm {
        new LensCreate2(lensCreate2Owner); // Preventing UnknownCodeHash error in zkSync
        // TODO: Add forking check later if needed
        // if (!fork) {
        // deployCodeTo("LensCreate2.sol", abi.encode(lensCreate2Owner), LENS_CREATE_2_ADDRESS);
        // }
        vm.etch(LENS_CREATE_2_ADDRESS, vm.getCode("MockLensCreate2.sol:MockLensCreate2"));
        create2 = LensCreate2(LENS_CREATE_2_ADDRESS);

        MockLensCreate2(LENS_CREATE_2_ADDRESS).initialize(lensCreate2Owner);

        IMPLEMENTATION = address(new ActionHub());
        PROXY_ADMIN = makeAddr("PROXY_ADMIN_1");
        INITIALIZER_CALL = "";
        SALT = keccak256("lens.contract.ActionHub");
        EXPECTED_ADDRESS = create2.getAddress(SALT);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_expectedAddressWithExpectedParams_sameAddress() public {
        vm.prank(lensCreate2Owner);
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
        vm.prank(lensCreate2Owner);
        address deployedContract = create2.createTransparentUpgradeableProxy({
            salt: SALT,
            implementation: IMPLEMENTATION,
            proxyAdmin: PROXY_ADMIN,
            initializerCall: INITIALIZER_CALL,
            expectedAddress: EXPECTED_ADDRESS
        });
        assertEq(deployedContract, EXPECTED_ADDRESS);
        vm.expectRevert();
        vm.prank(lensCreate2Owner);
        create2.createTransparentUpgradeableProxy({
            salt: SALT,
            implementation: IMPLEMENTATION,
            proxyAdmin: PROXY_ADMIN,
            initializerCall: INITIALIZER_CALL,
            expectedAddress: EXPECTED_ADDRESS
        });
    }

    function test_diffProxyAdmin_sameAddress(address proxyAdmin) public {
        vm.prank(lensCreate2Owner);
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
        address newActionHub = address(new ActionHub());
        vm.prank(lensCreate2Owner);
        address deployedContract = create2.createTransparentUpgradeableProxy({
            salt: SALT,
            implementation: newActionHub,
            proxyAdmin: PROXY_ADMIN,
            initializerCall: INITIALIZER_CALL,
            expectedAddress: EXPECTED_ADDRESS
        });
        assertEq(deployedContract, EXPECTED_ADDRESS);
    }

    function test_diffInitCall_sameAddress() public {
        vm.skip(true); // TODO: Use a diff impl with initializer
        vm.prank(lensCreate2Owner);
        address deployedContract = create2.createTransparentUpgradeableProxy({
            salt: SALT,
            implementation: IMPLEMENTATION,
            proxyAdmin: PROXY_ADMIN,
            initializerCall: INITIALIZER_CALL,
            expectedAddress: EXPECTED_ADDRESS
        });
        assertEq(deployedContract, EXPECTED_ADDRESS);
    }

    function test_zeroSaltAddress() public view {
        address deployedContract = create2.getAddress(bytes32(0));
        assertEq(deployedContract, expectedZeroSaltAddress);
    }
}
