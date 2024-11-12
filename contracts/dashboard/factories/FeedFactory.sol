// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {Feed} from "./../../core/primitives/feed/Feed.sol";
import {RoleBasedAccessControl} from "./../../core/access/RoleBasedAccessControl.sol";
import {RuleConfiguration, DataElement} from "./../../core/types/Types.sol";

contract FeedFactory {
    event Lens_FeedFactory_Deployment(address indexed feed);

    IAccessControl internal immutable _factoryOwnedAccessControl;

    constructor() {
        _factoryOwnedAccessControl = new RoleBasedAccessControl({owner: address(this)});
    }

    function deployFeed(
        string memory metadataURI,
        IAccessControl accessControl,
        RuleConfiguration[] calldata rules,
        DataElement[] calldata extraData
    ) external returns (address) {
        Feed feed = new Feed(metadataURI, _factoryOwnedAccessControl);
        feed.addFeedRules(rules);
        feed.setExtraData(extraData);
        feed.setAccessControl(accessControl);
        emit Lens_FeedFactory_Deployment(address(feed));
        return address(feed);
    }
}