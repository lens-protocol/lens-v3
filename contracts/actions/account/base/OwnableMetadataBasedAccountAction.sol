// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Ownable} from "contracts/core/access/Ownable.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {BaseAccountAction} from "contracts/actions/account/base/BaseAccountAction.sol";

abstract contract OwnableMetadataBasedAccountAction is BaseAccountAction, Ownable, MetadataBased {
    event Lens_AccountAction_MetadataURISet(string metadataURI);

    constructor(address actionHub, address owner, string memory metadataURI) BaseAccountAction(actionHub) {
        _transferOwnership(owner);
        _setMetadataURI(metadataURI);
    }

    function _initialize(address owner, string memory metadataURI) internal {
        _transferOwnership(owner);
        _setMetadataURI(metadataURI);
    }

    function _emitMetadataURISet(string memory metadataURI, address /* source */ ) internal virtual override {
        emit Lens_AccountAction_MetadataURISet(metadataURI);
    }

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal virtual override onlyOwner {
        return;
    }
}
