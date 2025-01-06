// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Graph} from "contracts/core/primitives/graph/Graph.sol";
import {PermissionlessAccessControl} from "contracts/extensions/access/PermissionlessAccessControl.sol";
import {RuleChange, KeyValue} from "contracts/core/types/Types.sol";
import {IVersionedBeacon} from "contracts/core/interfaces/IVersionedBeacon.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {ProxyAdmin} from "contracts/core/upgradeability/ProxyAdmin.sol";

contract GraphFactory {
    event Lens_GraphFactory_Deployment(address indexed graph, string metadataURI);

    IAccessControl internal immutable _temporaryAccessControl;
    address internal immutable _beacon;
    address internal immutable _proxyBeaconLock;

    constructor(address beacon, address proxyBeaconLock) {
        _temporaryAccessControl = new PermissionlessAccessControl();
        _beacon = beacon;
        _proxyBeaconLock = proxyBeaconLock;
    }

    function deployGraph(
        string memory metadataURI,
        IAccessControl accessControl,
        address proxyAdminOwner,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        address proxyAdmin = address(new ProxyAdmin(proxyAdminOwner, _proxyBeaconLock));
        Graph graph = Graph(address(new BeaconProxy(proxyAdmin, _beacon)));
        graph.initialize(metadataURI, _temporaryAccessControl);
        graph.changeGraphRules(ruleChanges);
        graph.setExtraData(extraData);
        graph.setAccessControl(accessControl);
        emit Lens_GraphFactory_Deployment(address(graph), metadataURI);
        return address(graph);
    }
}
