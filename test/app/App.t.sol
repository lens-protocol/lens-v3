// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../helpers/TypeHelpers.sol";
import {App, AppInitialProperties} from "contracts/extensions/primitives/app/App.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "contracts/extensions/access/OwnerAdminOnlyAccessControl.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";

contract AppTest is Test, BaseDeployments {
    IAccessControl accessControl;
    App app;

    function setUp() public override {
        super.setUp();
        accessControl = new OwnerAdminOnlyAccessControl(address(this), address(accessControlLock));
    }

    function testCanInitializeWithValues() public {
        app = App(
            lensFactory.deployApp({
                metadataURI: "",
                sourceStampVerificationEnabled: false,
                owner: address(this),
                admins: _emptyAddressArray(),
                initialProperties: AppInitialProperties({
                    graph: graphImpl,
                    feeds: _toAddressArray(feedImpl),
                    namespace: namespaceImpl,
                    groups: _toAddressArray(groupImpl),
                    defaultFeed: feedImpl,
                    signers: _emptyAddressArray(),
                    paymaster: makeAddr("PAYMASTER"),
                    treasury: makeAddr("TREASURY")
                }),
                extraData: _emptyKeyValueArray()
            })
        );
    }

    function testCanInitializeEmpty() public {
        app = App(
            lensFactory.deployApp({
                metadataURI: "",
                sourceStampVerificationEnabled: false,
                owner: address(this),
                admins: _emptyAddressArray(),
                initialProperties: AppInitialProperties({
                    graph: address(0),
                    feeds: _emptyAddressArray(),
                    namespace: address(0),
                    groups: _emptyAddressArray(),
                    defaultFeed: address(0),
                    signers: _emptyAddressArray(),
                    paymaster: address(0),
                    treasury: address(0)
                }),
                extraData: _emptyKeyValueArray()
            })
        );
    }
}
