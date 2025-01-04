// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IAccessControl} from "./../contracts/core/interfaces/IAccessControl.sol";
import {ITokenURIProvider} from "./../contracts/core/interfaces/ITokenURIProvider.sol";

import {RoleBasedAccessControl} from "./../contracts/core/access/RoleBasedAccessControl.sol";
import {LensUsernameTokenURIProvider} from "./../contracts/core/primitives/namespace/LensUsernameTokenURIProvider.sol";

import {App} from "./../contracts/dashboard/primitives/app/App.sol";
import {Feed} from "./../contracts/core/primitives/feed/Feed.sol";
import {Graph} from "./../contracts/core/primitives/graph/Graph.sol";
import {Group} from "./../contracts/core/primitives/group/Group.sol";
import {Namespace} from "./../contracts/core/primitives/namespace/Namespace.sol";

import {AccessControlFactory} from "./../contracts/dashboard/factories/AccessControlFactory.sol";
import {AccountFactory} from "./../contracts/dashboard/factories/AccountFactory.sol";

import {AppFactory} from "./../contracts/dashboard/factories/AppFactory.sol";
import {FeedFactory} from "./../contracts/dashboard/factories/FeedFactory.sol";
import {GraphFactory} from "./../contracts/dashboard/factories/GraphFactory.sol";
import {GroupFactory} from "./../contracts/dashboard/factories/GroupFactory.sol";
import {NamespaceFactory} from "./../contracts/dashboard/factories/NamespaceFactory.sol";
import {LensFactory} from "./../contracts/dashboard/factories/LensFactory.sol";

import {Lock} from "./../contracts/core/upgradeability/Lock.sol";
import {Beacon} from "./../contracts/core/upgradeability/Beacon.sol";

import {AccountBlockingRule} from "./../contracts/rules/base/AccountBlockingRule.sol";
import {GroupGatedFeedRule} from "./../contracts/rules/feed/GroupGatedFeedRule.sol";

contract MyScript is Script {
    IAccessControl simpleAccessControl;
    ITokenURIProvider simpleTokenURIProvider;
    address proxyAdminLock;
    address lockOwner = makeAddr("LOCK_OWNER");

    address appImpl;
    address feedImpl;
    address graphImpl;
    address groupImpl;
    address namespaceImpl;

    address appBeacon;
    address feedBeacon;
    address graphBeacon;
    address groupBeacon;
    address namespaceBeacon;

    FeedFactory feedFactory;
    GraphFactory graphFactory;
    GroupFactory groupFactory;
    NamespaceFactory namespaceFactory;
    AppFactory appFactory;

    LensFactory lensFactory;

    address accountBlockingRule;
    address groupGatedFeedRule;

    function run() external {
        proxyAdminLock = address(new Lock(lockOwner, true));
        _deployImplementations();
        _deployBeacons();
        _deployFactories();

        accountBlockingRule = address(new AccountBlockingRule({metadataURI: "uri://any"}));
        groupGatedFeedRule = address(new GroupGatedFeedRule({metadataURI: "uri://any"}));

        lensFactory = new LensFactory({
            accessControlFactory: new AccessControlFactory(),
            accountFactory: new AccountFactory(),
            appFactory: appFactory,
            groupFactory: groupFactory,
            feedFactory: feedFactory,
            graphFactory: graphFactory,
            namespaceFactory: namespaceFactory,
            accountBlockingRule: accountBlockingRule,
            groupGatedFeedRule: groupGatedFeedRule
        });
    }

    function _deployImplementations() internal {
        simpleAccessControl = IAccessControl(new RoleBasedAccessControl({owner: address(this)}));
        simpleTokenURIProvider = new LensUsernameTokenURIProvider();

        appImpl = address(new App());

        feedImpl = address(new Feed());
        graphImpl = address(new Graph());
        groupImpl = address(new Group());
        namespaceImpl = address(new Namespace());
    }

    function _deployBeacons() internal {
        appBeacon = address(new Beacon(lockOwner, 1, appImpl));

        feedBeacon = address(new Beacon(lockOwner, 1, feedImpl));
        graphBeacon = address(new Beacon(lockOwner, 1, graphImpl));
        groupBeacon = address(new Beacon(lockOwner, 1, groupImpl));
        namespaceBeacon = address(new Beacon(lockOwner, 1, namespaceImpl));
    }

    function _deployFactories() internal {
        appFactory = new AppFactory(appBeacon, proxyAdminLock);

        feedFactory = new FeedFactory(feedBeacon, proxyAdminLock);
        graphFactory = new GraphFactory(graphBeacon, proxyAdminLock);
        groupFactory = new GroupFactory(groupBeacon, proxyAdminLock);
        namespaceFactory = new NamespaceFactory(namespaceBeacon, proxyAdminLock);
    }
}
