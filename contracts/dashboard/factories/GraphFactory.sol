// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {Graph} from "./../../core/primitives/graph/Graph.sol";
import {RoleBasedAccessControl} from "./../../core/access/RoleBasedAccessControl.sol";
import {RuleConfigurationChange, RuleSelectorChange, KeyValue} from "./../../core/types/Types.sol";

contract GraphFactory {
    event Lens_GraphFactory_Deployment(address indexed graph, string metadataURI);

    IAccessControl internal immutable _factoryOwnedAccessControl;

    constructor() {
        _factoryOwnedAccessControl = new RoleBasedAccessControl({owner: address(this)});
    }

    function deployGraph(
        string memory metadataURI,
        IAccessControl accessControl,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        Graph graph = new Graph(metadataURI, _factoryOwnedAccessControl);
        graph.changeGraphRules(configChanges, selectorChanges);
        graph.setExtraData(extraData);
        graph.setAccessControl(accessControl);
        emit Lens_GraphFactory_Deployment(address(graph), metadataURI);
        return address(graph);
    }
}
