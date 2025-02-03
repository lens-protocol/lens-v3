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

import {MigrationApp} from "contracts/migration/primitives/MigrationApp.sol";
import {MigrationAccount} from "contracts/migration/primitives/MigrationAccount.sol";
import {MigrationFeed} from "contracts/migration/primitives/MigrationFeed.sol";
import {MigrationGraph} from "contracts/migration/primitives/MigrationGraph.sol";
import {MigrationNamespace} from "contracts/migration/primitives/MigrationNamespace.sol";

import {MigrationAccessControlFactory} from "contracts/migration/factories/MigrationAccessControlFactory.sol";
import {MigrationAppFactory} from "contracts/migration/factories/MigrationAppFactory.sol";
import {MigrationAccountFactory} from "contracts/migration/factories/MigrationAccountFactory.sol";
import {MigrationFeedFactory} from "contracts/migration/factories/MigrationFeedFactory.sol";
import {MigrationGraphFactory} from "contracts/migration/factories/MigrationGraphFactory.sol";
import {MigrationNamespaceFactory} from "contracts/migration/factories/MigrationNamespaceFactory.sol";
import {MigrationLensFactory} from "contracts/migration/factories/MigrationLensFactory.sol";

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

import {AccountBlockingRule} from "contracts/rules/AccountBlockingRule.sol";
import {GroupGatedFeedRule} from "contracts/rules/feed/GroupGatedFeedRule.sol";
import {UsernameSimpleCharsetNamespaceRule} from "contracts/rules/namespace/UsernameSimpleCharsetNamespaceRule.sol";
import {BanMemberGroupRule} from "contracts/rules/group/BanMemberGroupRule.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract BaseDeployments is Test {
    function testBaseDeployments() public {
        // Prevents being counted in Foundry Coverage
    }

    IAccessControl simpleAccessControl;
    ITokenURIProvider simpleTokenURIProvider;
    address proxyAdminLock;
    address accessControlLock;

    address proxyAdminLockOwner = vm.envOr("PROXY_ADMIN_LOCK_OWNER", makeAddr("PROXY_ADMIN_LOCK_OWNER"));
    address accessControlLockOwner = vm.envOr("ACCESS_CONTROL_LOCK_OWNER", makeAddr("ACCESS_CONTROL_LOCK_OWNER"));
    address rulesOwner = vm.envOr("RULES_OWNER", makeAddr("RULES_OWNER"));
    address actionsOwner = vm.envOr("ACTIONS_OWNER", makeAddr("ACTIONS_OWNER"));
    address beaconOwner = vm.envOr("BEACON_OWNER", makeAddr("BEACON_OWNER"));
    address factoriesProxyOwner = vm.envOr("FACTORIES_PROXY_OWNER", makeAddr("FACTORIES_PROXY_OWNER"));
    address primitivesOwner = vm.envOr("PRIMITIVES_OWNER", makeAddr("PRIMITIVES_OWNER"));

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
    AccessControlFactory accessControlFactory;
    AccountFactory accountFactory;
    FeedFactory feedFactory;
    GraphFactory graphFactory;
    GroupFactory groupFactory;
    NamespaceFactory namespaceFactory;

    LensFactory lensFactory;

    address accountBlockingRule;
    address groupGatedFeedRule;
    address usernameSimpleCharsetRule;
    address banMemberGroupRule;

    bool migrationMode = vm.envOr("MIGRATION_TESTS", false);

    function switchMigrationMode(bool newMigrationMode) public {
        migrationMode = newMigrationMode;
    }

    function setUp() public virtual {
        proxyAdminLock = address(new Lock(proxyAdminLockOwner, true));
        accessControlLock = address(new Lock(accessControlLockOwner, true));
        _deployImplementations();
        _deployBeacons();
        _deployFactories();

        accountBlockingRule = address(new AccountBlockingRule({owner: rulesOwner, metadataURI: "uri://any"}));
        groupGatedFeedRule = address(new GroupGatedFeedRule({owner: rulesOwner, metadataURI: "uri://any"}));
        usernameSimpleCharsetRule =
            address(new UsernameSimpleCharsetNamespaceRule({owner: rulesOwner, metadataURI: "uri://any"}));
        banMemberGroupRule = address(new BanMemberGroupRule({owner: rulesOwner, metadataURI: "uri://any"}));

        address lensFactoryImpl = migrationMode
            ? address(
                new MigrationLensFactory({
                    accessControlFactory: accessControlFactory,
                    accountFactory: accountFactory,
                    appFactory: appFactory,
                    groupFactory: groupFactory,
                    feedFactory: feedFactory,
                    graphFactory: graphFactory,
                    namespaceFactory: namespaceFactory,
                    accountBlockingRule: address(0),
                    groupGatedFeedRule: address(0),
                    usernameSimpleCharsetRule: address(0),
                    banMemberGroupRule: address(0)
                })
            )
            : address(
                new LensFactory({
                    accessControlFactory: accessControlFactory,
                    accountFactory: accountFactory,
                    appFactory: appFactory,
                    groupFactory: groupFactory,
                    feedFactory: feedFactory,
                    graphFactory: graphFactory,
                    namespaceFactory: namespaceFactory,
                    accountBlockingRule: accountBlockingRule,
                    groupGatedFeedRule: groupGatedFeedRule,
                    usernameSimpleCharsetRule: usernameSimpleCharsetRule,
                    banMemberGroupRule: banMemberGroupRule
                })
            );
        TransparentUpgradeableProxy lensFactoryProxy =
            new TransparentUpgradeableProxy(address(lensFactoryImpl), factoriesProxyOwner, "");

        lensFactory = LensFactory(address(lensFactoryProxy));
    }

    function _deployImplementations() internal {
        simpleAccessControl = IAccessControl(new RoleBasedAccessControl({owner: address(this)}));
        simpleTokenURIProvider = new LensUsernameTokenURIProvider();

        appImpl = migrationMode ? address(new MigrationApp()) : address(new App());
        accountImpl = migrationMode ? address(new MigrationAccount()) : address(new AccountContract());
        feedImpl = migrationMode ? address(new MigrationFeed()) : address(new Feed());
        graphImpl = migrationMode ? address(new MigrationGraph()) : address(new Graph());
        groupImpl = address(new Group());
        namespaceImpl = migrationMode ? address(new MigrationNamespace()) : address(new Namespace());
    }

    function _deployBeacons() internal {
        appBeacon = address(new Beacon(beaconOwner, 1, appImpl));
        accountBeacon = address(new Beacon(beaconOwner, 1, accountImpl));
        feedBeacon = address(new Beacon(beaconOwner, 1, feedImpl));
        graphBeacon = address(new Beacon(beaconOwner, 1, graphImpl));
        groupBeacon = address(new Beacon(beaconOwner, 1, groupImpl));
        namespaceBeacon = address(new Beacon(beaconOwner, 1, namespaceImpl));
    }

    function _deployFactories() internal {
        address accessControlFactoryImpl = migrationMode
            ? address(new MigrationAccessControlFactory(accessControlLock))
            : address(new AccessControlFactory(accessControlLock));
        TransparentUpgradeableProxy accessControlFactoryProxy =
            new TransparentUpgradeableProxy(accessControlFactoryImpl, factoriesProxyOwner, "");
        accessControlFactory = AccessControlFactory(address(accessControlFactoryProxy));

        address accountFactoryImpl = migrationMode
            ? address(new MigrationAccountFactory(accountBeacon, proxyAdminLock))
            : address(new AccountFactory(accountBeacon, proxyAdminLock));
        TransparentUpgradeableProxy accountFactoryProxy =
            new TransparentUpgradeableProxy(accountFactoryImpl, factoriesProxyOwner, "");
        accountFactory = AccountFactory(address(accountFactoryProxy));

        address appFactoryImpl = migrationMode
            ? address(new MigrationAppFactory(appBeacon, proxyAdminLock))
            : address(new AppFactory(appBeacon, proxyAdminLock));
        TransparentUpgradeableProxy appFactoryProxy =
            new TransparentUpgradeableProxy(appFactoryImpl, factoriesProxyOwner, "");
        appFactory = AppFactory(address(appFactoryProxy));

        address feedFactoryImpl = migrationMode
            ? address(new MigrationFeedFactory(feedBeacon, proxyAdminLock))
            : address(new FeedFactory(feedBeacon, proxyAdminLock));
        TransparentUpgradeableProxy feedFactoryProxy =
            new TransparentUpgradeableProxy(address(feedFactoryImpl), factoriesProxyOwner, "");
        feedFactory = FeedFactory(address(feedFactoryProxy));

        address graphFactoryImpl = migrationMode
            ? address(new MigrationGraphFactory(graphBeacon, proxyAdminLock))
            : address(new GraphFactory(graphBeacon, proxyAdminLock));
        TransparentUpgradeableProxy graphFactoryProxy =
            new TransparentUpgradeableProxy(graphFactoryImpl, factoriesProxyOwner, "");
        graphFactory = GraphFactory(address(graphFactoryProxy));

        address groupFactoryImpl = address(new GroupFactory(groupBeacon, proxyAdminLock));
        TransparentUpgradeableProxy groupFactoryProxy =
            new TransparentUpgradeableProxy(groupFactoryImpl, factoriesProxyOwner, "");
        groupFactory = GroupFactory(address(groupFactoryProxy));

        address namespaceFactoryImpl = migrationMode
            ? address(new MigrationNamespaceFactory(namespaceBeacon, proxyAdminLock))
            : address(new NamespaceFactory(namespaceBeacon, proxyAdminLock));
        TransparentUpgradeableProxy namespaceFactoryProxy =
            new TransparentUpgradeableProxy(namespaceFactoryImpl, factoriesProxyOwner, "");
        namespaceFactory = NamespaceFactory(address(namespaceFactoryProxy));
    }
}
