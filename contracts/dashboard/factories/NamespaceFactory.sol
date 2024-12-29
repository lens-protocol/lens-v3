// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {Namespace} from "./../../core/primitives/namespace/Namespace.sol";
import {RoleBasedAccessControl} from "./../../core/access/RoleBasedAccessControl.sol";
import {RuleChange, KeyValue} from "./../../core/types/Types.sol";
import {ITokenURIProvider} from "./../../core/interfaces/ITokenURIProvider.sol";

contract NamespaceFactory {
    event Lens_NamespaceFactory_Deployment(address indexed namespaceAddress, string namespace, string metadataURI);

    IAccessControl internal immutable _factoryOwnedAccessControl;

    constructor() {
        _factoryOwnedAccessControl = new RoleBasedAccessControl({owner: address(this)});
    }

    function deployNamespace(
        string memory namespace,
        string memory metadataURI,
        IAccessControl accessControl,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData,
        string memory nftName,
        string memory nftSymbol,
        ITokenURIProvider tokenURIProvider
    ) external returns (address) {
        Namespace namespacePrimitive =
            new Namespace(namespace, metadataURI, _factoryOwnedAccessControl, nftName, nftSymbol, tokenURIProvider);
        namespacePrimitive.changeNamespaceRules(ruleChanges);
        namespacePrimitive.setExtraData(extraData);
        namespacePrimitive.setAccessControl(accessControl);
        emit Lens_NamespaceFactory_Deployment(address(namespacePrimitive), namespace, metadataURI);
        return address(namespacePrimitive);
    }
}
