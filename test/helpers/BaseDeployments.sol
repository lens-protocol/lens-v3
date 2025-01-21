// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {ITokenURIProvider} from "contracts/core/interfaces/ITokenURIProvider.sol";

import {RoleBasedAccessControl} from "contracts/core/access/RoleBasedAccessControl.sol";
import {LensUsernameTokenURIProvider} from "contracts/core/primitives/namespace/LensUsernameTokenURIProvider.sol";

import {App} from "@extensions/primitives/app/App.sol";
import {Account as AccountContract} from "@extensions/account/Account.sol";
import {Feed} from "contracts/core/primitives/feed/Feed.sol";
import {Graph} from "contracts/core/primitives/graph/Graph.sol";
import {Group} from "contracts/core/primitives/group/Group.sol";
import {Namespace} from "contracts/core/primitives/namespace/Namespace.sol";

import {AccessControlFactory} from "@extensions/factories/AccessControlFactory.sol";
import {AccountFactory} from "@extensions/factories/AccountFactory.sol";

import {AppFactory} from "@extensions/factories/AppFactory.sol";
import {FeedFactory} from "@extensions/factories/FeedFactory.sol";
import {GraphFactory} from "@extensions/factories/GraphFactory.sol";
import {GroupFactory} from "@extensions/factories/GroupFactory.sol";
import {NamespaceFactory} from "@extensions/factories/NamespaceFactory.sol";
import {LensFactory} from "@extensions/factories/LensFactory.sol";

import {Lock} from "contracts/core/upgradeability/Lock.sol";
import {Beacon} from "contracts/core/upgradeability/Beacon.sol";

import {AccountBlockingRule} from "contracts/rules/base/AccountBlockingRule.sol";
import {GroupGatedFeedRule} from "contracts/rules/feed/GroupGatedFeedRule.sol";
import {UsernameSimpleCharsetNamespaceRule} from "contracts/rules/namespace/UsernameSimpleCharsetNamespaceRule.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract BaseDeployments is Test {
    IAccessControl simpleAccessControl;
    ITokenURIProvider simpleTokenURIProvider;
    address proxyAdminLock;
    address lockOwner = makeAddr("LOCK_OWNER");

    address appImpl;
    address accountImpl;
    address feedImpl;
    address graphImpl;
    address groupImpl;
    address namespaceImpl;

    address appBeacon;
    address accountBeacon;
    address feedBeacon;
    address graphBeacon;
    address groupBeacon;
    address namespaceBeacon;

    AppFactory appFactory;
    AccountFactory accountFactory;
    FeedFactory feedFactory;
    GraphFactory graphFactory;
    GroupFactory groupFactory;
    NamespaceFactory namespaceFactory;

    LensFactory lensFactory;

    address accountBlockingRule;
    address groupGatedFeedRule;
    address usernameSimpleCharsetRule;

    function setUp() public virtual {
        proxyAdminLock = address(new Lock(lockOwner, true));
        _deployImplementations();
        _deployBeacons();
        _deployFactories();

        accountBlockingRule = address(new AccountBlockingRule({owner: address(this), metadataURI: "uri://any"}));
        groupGatedFeedRule = address(new GroupGatedFeedRule({owner: address(this), metadataURI: "uri://any"}));
        usernameSimpleCharsetRule =
            address(new UsernameSimpleCharsetNamespaceRule({owner: address(this), metadataURI: "uri://any"}));

        lensFactory = new LensFactory({
            accessControlFactory: new AccessControlFactory(),
            accountFactory: accountFactory,
            appFactory: appFactory,
            groupFactory: groupFactory,
            feedFactory: feedFactory,
            graphFactory: graphFactory,
            namespaceFactory: namespaceFactory,
            accountBlockingRule: accountBlockingRule,
            groupGatedFeedRule: groupGatedFeedRule,
            usernameSimpleCharsetRule: usernameSimpleCharsetRule
        });
    }

    function _deployImplementations() internal {
        simpleAccessControl = IAccessControl(new RoleBasedAccessControl({owner: address(this)}));
        simpleTokenURIProvider = new LensUsernameTokenURIProvider();

        appImpl = address(new App());
        accountImpl = address(new AccountContract());
        feedImpl = address(new Feed());
        graphImpl = address(new Graph());
        groupImpl = address(new Group());
        namespaceImpl = address(new Namespace());
    }

    function _deployBeacons() internal {
        appBeacon = address(new Beacon(lockOwner, 1, appImpl));
        accountBeacon = address(new Beacon(lockOwner, 1, accountImpl));
        feedBeacon = address(new Beacon(lockOwner, 1, feedImpl));
        graphBeacon = address(new Beacon(lockOwner, 1, graphImpl));
        groupBeacon = address(new Beacon(lockOwner, 1, groupImpl));
        namespaceBeacon = address(new Beacon(lockOwner, 1, namespaceImpl));
    }

    function _deployFactories() internal {
        appFactory = new AppFactory(appBeacon, proxyAdminLock);
        accountFactory = new AccountFactory(accountBeacon, proxyAdminLock);

        address feedFactoryImpl = address(new FeedFactory(feedBeacon, proxyAdminLock));
        TransparentUpgradeableProxy feedFactoryProxy =
            new TransparentUpgradeableProxy(address(feedFactoryImpl), proxyAdminLock, "");
        feedFactory = FeedFactory(address(feedFactoryProxy));

        graphFactory = new GraphFactory(graphBeacon, proxyAdminLock);
        groupFactory = new GroupFactory(groupBeacon, proxyAdminLock);
        namespaceFactory = new NamespaceFactory(namespaceBeacon, proxyAdminLock);
    }
}
