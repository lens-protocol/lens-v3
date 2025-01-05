// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Feed} from "contracts/core/primitives/feed/Feed.sol";
import {RoleBasedAccessControl} from "contracts/core/access/RoleBasedAccessControl.sol";
import {RuleChange, KeyValue} from "contracts/core/types/Types.sol";
import {IVersionedBeacon} from "contracts/core/interfaces/IVersionedBeacon.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {ProxyAdmin} from "contracts/core/upgradeability/ProxyAdmin.sol";

contract FeedFactory {
    event Lens_FeedFactory_Deployment(address indexed feed, string metadataURI);

    IAccessControl internal immutable _factoryOwnedAccessControl;
    address internal immutable _beacon;
    address internal immutable _lock;

    constructor(address beacon, address lock) {
        _factoryOwnedAccessControl = new RoleBasedAccessControl({owner: address(this)});
        _beacon = beacon;
        _lock = lock;
    }

    function deployFeed(
        string memory metadataURI,
        IAccessControl accessControl,
        address proxyAdminOwner,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        address proxyAdmin = address(new ProxyAdmin(proxyAdminOwner, _lock));
        Feed feed = Feed(address(new BeaconProxy(proxyAdmin, _beacon)));
        feed.initialize(metadataURI, _factoryOwnedAccessControl);
        feed.changeFeedRules(ruleChanges);
        feed.setExtraData(extraData);
        feed.setAccessControl(accessControl);
        emit Lens_FeedFactory_Deployment(address(feed), metadataURI);
        return address(feed);
    }
}
