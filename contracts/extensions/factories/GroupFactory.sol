// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Group} from "contracts/core/primitives/group/Group.sol";
import {PermissionlessAccessControl} from "contracts/extensions/access/PermissionlessAccessControl.sol";
import {RuleChange, KeyValue} from "contracts/core/types/Types.sol";
import {IVersionedBeacon} from "contracts/core/interfaces/IVersionedBeacon.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {ProxyAdmin} from "contracts/core/upgradeability/ProxyAdmin.sol";

contract GroupFactory {
    event Lens_GroupFactory_Deployment(address indexed group, string metadataURI);

    IAccessControl internal immutable _temporaryAccessControl;
    address internal immutable _beacon;
    address internal immutable _proxyBeaconLock;

    constructor(address beacon, address proxyBeaconLock) {
        _temporaryAccessControl = new PermissionlessAccessControl();
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
        group.initialize(metadataURI, _temporaryAccessControl);
        group.changeGroupRules(ruleChanges);
        group.setExtraData(extraData);
        group.setAccessControl(accessControl);
        emit Lens_GroupFactory_Deployment(address(group), metadataURI);
        return address(group);
    }
}
