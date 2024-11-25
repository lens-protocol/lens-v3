// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {Feed} from "@core/primitives/feed/Feed.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";

contract DashboardFeed is Feed {
    constructor(string memory metadataURI, IAccessControl accessControl) Feed(metadataURI, accessControl) {
        require(accessControl.getType() == keccak256("lens.access-control.owner-admin-only-access-control"));
    }

    // TODO: Make internal function so can be overridden and called with super._setAccessControl...
    function setAccessControl(IAccessControl newAccessControl) external override {
        require(newAccessControl.getType() == keccak256("lens.access-control.owner-admin-only-access-control"));
        super.setAccessControl(newAccessControl);
    }
}
