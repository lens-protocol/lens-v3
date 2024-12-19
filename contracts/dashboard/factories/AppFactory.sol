// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {AppInitialProperties, App} from "./../primitives/app/App.sol";
import {KeyValue} from "./../../core/types/Types.sol";

contract AppFactory {
    event Lens_AppFactory_Deployment(address indexed app, string metadataURI);

    function deployApp(
        string memory metadataURI,
        bool sourceStampVerificationEnabled,
        IAccessControl accessControl,
        AppInitialProperties calldata initialProperties,
        KeyValue[] calldata extraData
    ) external returns (address) {
        App app = new App(metadataURI, sourceStampVerificationEnabled, accessControl, initialProperties, extraData);
        emit Lens_AppFactory_Deployment(address(app), metadataURI);
        return address(app);
    }
}
