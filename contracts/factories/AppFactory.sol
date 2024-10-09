// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "./../primitives/access-control/IAccessControl.sol";
import {AppInitialProperties, App} from "./../primitives/app/App.sol";
import {DataElement} from "./../types/Types.sol";

contract AppFactory {
    event Lens_AppFactory_Deployment(address indexed app);

    function deployApp(
        string memory metadataURI,
        IAccessControl accessControl,
        AppInitialProperties calldata initialProperties,
        DataElement[] calldata extraData
    ) external returns (address) {
        App app = new App(metadataURI, accessControl, initialProperties, extraData);
        emit Lens_AppFactory_Deployment(address(app));
        return address(app);
    }
}
