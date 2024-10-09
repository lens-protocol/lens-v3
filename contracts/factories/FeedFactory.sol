// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "./../primitives/access-control/IAccessControl.sol";
import {Feed} from "./../primitives/feed/Feed.sol";
import {OwnerOnlyAccessControl} from "./../primitives/access-control/OwnerOnlyAccessControl.sol";
import {RuleConfiguration, DataElement} from "./../types/Types.sol";

contract FeedFactory {
    event Lens_FeedFactory_Deployment(address indexed feed);

    IAccessControl internal immutable _factoryOwnedAccessControl;

    constructor() {
        _factoryOwnedAccessControl = new OwnerOnlyAccessControl({owner: address(this)});
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
