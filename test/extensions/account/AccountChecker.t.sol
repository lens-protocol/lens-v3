// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {BeaconProxy as LegacyBeaconProxy} from "contracts/core/upgradeability/LegacyBeaconProxy.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {IVersionedBeacon} from "contracts/core/interfaces/IVersionedBeacon.sol";
import {AccountChecker} from "contracts/helpers/AccountChecker.sol";

// This contraption can be used as a template for debugging on-chain transactions.

contract AccountCheckerTest is Test, BaseDeployments {
    AccountChecker accountChecker;

    function setUp() public override {
        accountChecker = new AccountChecker();
    }

    function testIsLensAccount() public onlyFork {
        address oldLensAccount = 0x6a53Aae71f64CEc3ab7dB71865450AC71B3f8f9b;
        address newLensAccount = 0x85ba80402F2BD3EC680150c837681cCbcD874CB3;
        address someApp = 0x8A5Cc31180c37078e1EbA2A23c861Acf351a97cE;
        address eoa = makeAddr("EOA");
        assertTrue(accountChecker.isLensAccount(oldLensAccount));
        assertTrue(accountChecker.isLensAccount(newLensAccount));
        assertFalse(accountChecker.isLensAccount(someApp));
        assertFalse(accountChecker.isLensAccount(eoa));
    }
}
