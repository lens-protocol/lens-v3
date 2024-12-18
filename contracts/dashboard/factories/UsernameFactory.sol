// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {Username} from "./../../core/primitives/username/Username.sol";
import {RoleBasedAccessControl} from "./../../core/access/RoleBasedAccessControl.sol";
import {RuleChange, KeyValue} from "./../../core/types/Types.sol";
import {ITokenURIProvider} from "./../../core/interfaces/ITokenURIProvider.sol";

contract UsernameFactory {
    event Lens_UsernameFactory_Deployment(address indexed username, string namespace, string metadataURI);

    IAccessControl internal immutable _factoryOwnedAccessControl;

    constructor() {
        _factoryOwnedAccessControl = new RoleBasedAccessControl({owner: address(this)});
    }

    function deployUsername(
        string memory namespace,
        string memory metadataURI,
        IAccessControl accessControl,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData,
        string memory nftName,
        string memory nftSymbol,
        ITokenURIProvider tokenURIProvider
    ) external returns (address) {
        Username username =
            new Username(namespace, metadataURI, _factoryOwnedAccessControl, nftName, nftSymbol, tokenURIProvider);
        username.changeUsernameRules(ruleChanges);
        username.setExtraData(extraData);
        username.setAccessControl(accessControl);
        emit Lens_UsernameFactory_Deployment(address(username), namespace, metadataURI);
        return address(username);
    }
}
