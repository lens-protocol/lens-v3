// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {RoleBasedAccessControl} from "./../../core/access/RoleBasedAccessControl.sol";
import {RuleChange, KeyValue} from "./../../core/types/Types.sol";
import {IVersionedBeacon} from "./../../core/interfaces/IVersionedBeacon.sol";
import {BeaconProxy} from "./../../core/upgradeability/BeaconProxy.sol";
import {IFeed} from "./../../core/interfaces/IFeed.sol";
import {IAccessControlled} from "./../../core/interfaces/IAccessControlled.sol";

contract FeedFactory is IVersionedBeacon {
    event Lens_FeedFactory_Deployment(address indexed feed, string metadataURI);

    IAccessControl internal immutable _factoryOwnedAccessControl;
    address internal immutable _feedImplementation;

    constructor(address feedImplementation) {
        _factoryOwnedAccessControl = new RoleBasedAccessControl({owner: address(this)});
        _feedImplementation = feedImplementation;
    }

    function implementation() external view returns (address) {
        return _feedImplementation;
    }

    function implementation(uint256 /* implementationVersion */ ) external view returns (address) {
        return _feedImplementation;
    }

    function deployFeed(
        string memory metadataURI,
        IAccessControl accessControl,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        IFeed feed = IFeed(address(new BeaconProxy(address(this), address(this))));
        feed.initialize(metadataURI, accessControl);
        feed.changeFeedRules(ruleChanges);
        feed.setExtraData(extraData);
        IAccessControlled(address(feed)).setAccessControl(accessControl);
        emit Lens_FeedFactory_Deployment(address(feed), metadataURI);
        return address(feed);
    }
}
