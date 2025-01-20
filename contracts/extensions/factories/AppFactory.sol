// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AppInitialProperties, App} from "contracts/extensions/primitives/app/App.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {ProxyAdmin} from "contracts/core/upgradeability/ProxyAdmin.sol";

contract AppFactory {
    event Lens_AppFactory_Deployment(address indexed app, string metadataURI, KeyValue[] extraData);

    address internal immutable _beacon;
    address internal immutable _lock;

    constructor(address beacon, address lock) {
        _beacon = beacon;
        _lock = lock;
    }

    function deployApp(
        string memory metadataURI,
        bool sourceStampVerificationEnabled,
        IAccessControl accessControl,
        address proxyAdminOwner,
        AppInitialProperties calldata initialProperties,
        KeyValue[] calldata extraData
    ) external returns (address) {
        address proxyAdmin = address(new ProxyAdmin(proxyAdminOwner, _lock));
        App app = App(address(new BeaconProxy(proxyAdmin, _beacon)));
        app.initialize(metadataURI, sourceStampVerificationEnabled, accessControl, initialProperties, extraData);
        emit Lens_AppFactory_Deployment(address(app), metadataURI, extraData);
        return address(app);
    }
}
