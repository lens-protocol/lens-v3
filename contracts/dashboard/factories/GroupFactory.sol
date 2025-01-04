// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {Group} from "./../../core/primitives/group/Group.sol";
import {RoleBasedAccessControl} from "./../../core/access/RoleBasedAccessControl.sol";
import {RuleChange, KeyValue} from "./../../core/types/Types.sol";
import {IVersionedBeacon} from "contracts/core/interfaces/IVersionedBeacon.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {ProxyAdmin} from "contracts/core/upgradeability/ProxyAdmin.sol";

contract GroupFactory {
    event Lens_GroupFactory_Deployment(address indexed group, string metadataURI);

    IAccessControl internal immutable _factoryOwnedAccessControl;
    address internal immutable _beacon;
    address internal immutable _proxyBeaconLock;

    constructor(address beacon, address proxyBeaconLock) {
        _factoryOwnedAccessControl = new RoleBasedAccessControl({owner: address(this)});
        _beacon = beacon;
        _proxyBeaconLock = proxyBeaconLock;
    }

    function deployGroup(
        string memory metadataURI,
        IAccessControl accessControl,
        address proxyAdminOwner,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        address proxyAdmin = address(new ProxyAdmin(proxyAdminOwner, _proxyBeaconLock));
        Group group = Group(address(new BeaconProxy(proxyAdmin, _beacon)));
        group.initialize(metadataURI, _factoryOwnedAccessControl);
        group.changeGroupRules(ruleChanges);
        group.setExtraData(extraData);
        group.setAccessControl(accessControl);
        emit Lens_GroupFactory_Deployment(address(group), metadataURI);
        return address(group);
    }
}
