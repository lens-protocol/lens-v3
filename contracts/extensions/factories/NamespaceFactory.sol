// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Namespace} from "contracts/core/primitives/namespace/Namespace.sol";
import {PermissionlessAccessControl} from "contracts/extensions/access/PermissionlessAccessControl.sol";
import {RuleChange, KeyValue} from "contracts/core/types/Types.sol";
import {ITokenURIProvider} from "contracts/core/interfaces/ITokenURIProvider.sol";
import {IVersionedBeacon} from "contracts/core/interfaces/IVersionedBeacon.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {ProxyAdmin} from "contracts/core/upgradeability/ProxyAdmin.sol";

contract NamespaceFactory {
    event Lens_NamespaceFactory_Deployment(address indexed namespaceAddress, string namespace, string metadataURI);

    IAccessControl internal immutable _temporaryAccessControl;
    address internal immutable _beacon;
    address internal immutable _proxyBeaconLock;

    constructor(address beacon, address proxyBeaconLock) {
        _temporaryAccessControl = new PermissionlessAccessControl();
        _beacon = beacon;
        _proxyBeaconLock = proxyBeaconLock;
    }

    function deployNamespace(
        string memory namespace,
        string memory metadataURI,
        IAccessControl accessControl,
        address proxyAdminOwner,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData,
        string memory nftName,
        string memory nftSymbol,
        ITokenURIProvider tokenURIProvider
    ) external returns (address) {
        address proxyAdmin = address(new ProxyAdmin(proxyAdminOwner, _proxyBeaconLock));
        Namespace namespacePrimitive = Namespace(address(new BeaconProxy(proxyAdmin, _beacon)));
        namespacePrimitive.initialize(
            namespace, metadataURI, nftName, nftSymbol, tokenURIProvider, _temporaryAccessControl
        );
        namespacePrimitive.changeNamespaceRules(ruleChanges);
        namespacePrimitive.setExtraData(extraData);
        namespacePrimitive.setAccessControl(accessControl);
        emit Lens_NamespaceFactory_Deployment(address(namespacePrimitive), namespace, metadataURI);
        return address(namespacePrimitive);
    }
}
