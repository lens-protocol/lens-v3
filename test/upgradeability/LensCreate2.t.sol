// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {LENS_CREATE_2_ADDRESS, LensCreate2} from "@core/upgradeability/LensCreate2.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ActionHub} from "@extensions/actions/ActionHub.sol";
import {ZkTest} from "test/helpers/ZkTest.sol";
import {EmptyImplementation} from "@core/upgradeability/EmptyImplementation.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract LensCreate2Test is ZkTest {
    LensCreate2 create2;
    address IMPLEMENTATION;
    address PROXY_ADMIN;
    bytes INITIALIZER_CALL;
    address EXPECTED_ADDRESS;
    bytes32 SALT;

    address lensCreate2ProxyAdmin = makeAddr("LENS_CREATE_2_PROXY_ADMIN");
    address lensCreate2Owner = makeAddr("LENS_CREATE_2_OWNER");

    function setUp() public virtual onlyZkEvm {
        _deployLensCreate2To(LENS_CREATE_2_ADDRESS);

        // NOTE: Add fork-check later if needed
        // if (!fork) {
        //     deployCodeTo("LensCreate2.sol", abi.encode(lensCreate2Owner), LENS_CREATE_2_ADDRESS);
        // }

        IMPLEMENTATION = address(new ActionHub());
        PROXY_ADMIN = makeAddr("PROXY_ADMIN_1");
        INITIALIZER_CALL = "";
        SALT = keccak256("lens.contract.ActionHub");
        EXPECTED_ADDRESS = create2.getAddress(SALT);
    }

    function _deployLensCreate2To(address lensCreate2Address) internal {
        address emptyImpl = address(new EmptyImplementation());
        new TransparentUpgradeableProxy(emptyImpl, emptyImpl, ""); // Discarded, just to avoid UnknownCodeHash error
        vm.etch(lensCreate2Address, vm.getCode("TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy"));
        address create2Impl = address(new LensCreate2());
        vm.store(
            lensCreate2Address,
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
            bytes32(uint256(uint160(create2Impl)))
        );
        vm.store(
            lensCreate2Address,
            0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103, // bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
            bytes32(uint256(uint160(lensCreate2ProxyAdmin)))
        );
        create2 = LensCreate2(lensCreate2Address);
        create2.initialize(lensCreate2Owner);
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
        address EXPECTED_ZERO_SALT_ADDRESS = 0xff82e744035Bb7C86044F67314772Cbf87A8bBf2;
        address deployedContract = create2.getAddress(bytes32(0));
        assertEq(deployedContract, EXPECTED_ZERO_SALT_ADDRESS);
    }

    function test_calculateAddresses() public {
        vm.skip(true);
        string[] memory contractNames = new string[](24);
        contractNames[0] = "TippingAccountAction";
        contractNames[1] = "TippingPostAction";
        contractNames[2] = "SimpleCollectAction";
        contractNames[3] = "AccountBlockingRule";
        contractNames[4] = "GroupGatedFeedRule";
        contractNames[5] = "SimplePaymentFeedRule";
        contractNames[6] = "TokenGatedFeedRule";
        contractNames[7] = "SimplePaymentFollowRule";
        contractNames[8] = "TokenGatedFollowRule";
        contractNames[9] = "GroupGatedGraphRule";
        contractNames[10] = "TokenGatedGraphRule";
        contractNames[11] = "AdditionRemovalPidGroupRule";
        contractNames[12] = "BanMemberGroupRule";
        contractNames[13] = "MembershipApprovalGroupRule";
        contractNames[14] = "SimplePaymentGroupRule";
        contractNames[15] = "TokenGatedGroupRule";
        contractNames[16] = "TokenGatedNamespaceRule";
        contractNames[17] = "UsernameLengthNamespaceRule";
        contractNames[18] = "UsernamePricePerLengthNamespaceRule";
        contractNames[19] = "UsernameReservedNamespaceRule";
        contractNames[20] = "UsernameSimpleCharsetNamespaceRule";
        contractNames[21] = "FollowersOnlyPostRule";
        contractNames[22] = "ActionHub";
        contractNames[23] = "LensFees";
        for (uint256 i = 0; i < contractNames.length; i++) {
            string memory preSalt = string.concat("lens.contract.", contractNames[i]);
            bytes32 salt = keccak256(bytes(preSalt));
            address predictedAddress = create2.getAddress(salt);
            console.log("------------------------------");
            console.log("Contract: ", contractNames[i]);
            console.log("Pre-Salt: ", preSalt);
            console.log("Salt: ", Strings.toHexString(uint256(salt), 32));
            console.log("Address: ", Strings.toHexString(predictedAddress));
        }
        console.log("------------------------------");
        // This test is just a helper to log the address, no assertions.
    }
}
