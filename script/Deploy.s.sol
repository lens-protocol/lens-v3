// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IAccessControl} from "./../contracts/core/interfaces/IAccessControl.sol";
import {ITokenURIProvider} from "./../contracts/core/interfaces/ITokenURIProvider.sol";

import {RoleBasedAccessControl} from "./../contracts/core/access/RoleBasedAccessControl.sol";
import {LensUsernameTokenURIProvider} from "./../contracts/core/primitives/namespace/LensUsernameTokenURIProvider.sol";

import {Feed} from "./../contracts/core/primitives/feed/Feed.sol";
import {Graph} from "./../contracts/core/primitives/graph/Graph.sol";
import {Group} from "./../contracts/core/primitives/group/Group.sol";
import {Namespace} from "./../contracts/core/primitives/namespace/Namespace.sol";

import {FeedFactory} from "./../contracts/dashboard/factories/FeedFactory.sol";
import {GraphFactory} from "./../contracts/dashboard/factories/GraphFactory.sol";
import {GroupFactory} from "./../contracts/dashboard/factories/GroupFactory.sol";
import {NamespaceFactory} from "./../contracts/dashboard/factories/NamespaceFactory.sol";

contract MyScript is Script {
    IAccessControl simpleAccessControl;
    ITokenURIProvider simpleTokenURIProvider;

    function run() external {
        _deployPrimitives();
        _deployFactories();
    }

    function _deployFactories() internal {
        console.log("\n\nDeploying Factories:");

        uint256 gasBefore = gasleft();
        FeedFactory feedFactory = new FeedFactory();
        uint256 gasAfter = gasleft();
        console.log("   Gas used for FeedFactory Deployment: ", gasBefore - gasAfter);

        gasBefore = gasleft();
        GraphFactory graphFactory = new GraphFactory();
        gasAfter = gasleft();
        console.log("   Gas used for GraphFactory Deployment: ", gasBefore - gasAfter);

        gasBefore = gasleft();
        GroupFactory groupFactory = new GroupFactory();
        gasAfter = gasleft();
        console.log("   Gas used for GroupFactory Deployment: ", gasBefore - gasAfter);

        gasBefore = gasleft();
        NamespaceFactory namespaceFactory = new NamespaceFactory();
        gasAfter = gasleft();
        console.log("   Gas used for NamespaceFactory Deployment: ", gasBefore - gasAfter);
    }

    function _deployPrimitives() internal {
        console.log("\n\nDeploying individual primitives:");

        simpleAccessControl = IAccessControl(new RoleBasedAccessControl({owner: address(this)}));
        simpleTokenURIProvider = new LensUsernameTokenURIProvider();

        uint256 gasBefore = gasleft();
        _deployFeed("https://lens.dev/feed", simpleAccessControl);
        uint256 gasAfter = gasleft();
        console.log("   Gas used for Feed Deployment: ", gasBefore - gasAfter);

        gasBefore = gasleft();
        _deployGraph("https://lens.dev/graph", simpleAccessControl);
        gasAfter = gasleft();
        console.log("   Gas used for Graph Deployment: ", gasBefore - gasAfter);

        gasBefore = gasleft();
        _deployGroup("https://lens.dev/group", simpleAccessControl);
        gasAfter = gasleft();
        console.log("   Gas used for Group Deployment: ", gasBefore - gasAfter);

        gasBefore = gasleft();
        _deployNamespace(
            "lens", "https://lens.dev/username", simpleAccessControl, "Lens", "LENS", simpleTokenURIProvider
        );
        gasAfter = gasleft();
        console.log("   Gas used for Username Deployment: ", gasBefore - gasAfter);
    }

    function _deployFeed(string memory metadataURI, IAccessControl accessControl) internal {
        Feed feed = new Feed(metadataURI, accessControl);
    }

    function _deployGraph(string memory metadataURI, IAccessControl accessControl) internal {
        Graph graph = new Graph(metadataURI, accessControl);
    }

    function _deployGroup(string memory metadataURI, IAccessControl accessControl) internal {
        Group group = new Group(metadataURI, accessControl);
    }

    function _deployNamespace(
        string memory namespace,
        string memory metadataURI,
        IAccessControl accessControl,
        string memory nftName,
        string memory nftSymbol,
        ITokenURIProvider tokenURIProvider
    ) internal {
        Namespace namespacePrimitive =
            new Namespace(namespace, metadataURI, accessControl, nftName, nftSymbol, tokenURIProvider);
    }
}
