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
import {LensFactory, FactoryConstructorParams, RuleConstructorParams} from "@extensions/factories/LensFactory.sol";

import {Lock} from "contracts/core/upgradeability/Lock.sol";
import {Beacon} from "contracts/core/upgradeability/Beacon.sol";

import {AccountBlockingRule} from "contracts/rules/AccountBlockingRule.sol";
import {GroupGatedFeedRule} from "contracts/rules/feed/GroupGatedFeedRule.sol";
import {UsernameSimpleCharsetNamespaceRule} from "contracts/rules/namespace/UsernameSimpleCharsetNamespaceRule.sol";
import {BanMemberGroupRule} from "contracts/rules/group/BanMemberGroupRule.sol";
import {AdditionRemovalPidGroupRule} from "contracts/rules/group/AdditionRemovalPidGroupRule.sol";
import {UsernameReservedNamespaceRule} from "contracts/rules/namespace/UsernameReservedNamespaceRule.sol";

import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract BaseDeployments is Test {
    function testBaseDeployments() public {
        // Prevents being included in the foundry coverage report
    }

    using stdJson for string;

    string json;

    function _loadAddressBookJson() internal {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/addressBook.json"));
        assertTrue(vm.isFile(path), "Address book not found");
        json = vm.readFile(path);
    }

    IAccessControl simpleAccessControl;
    ITokenURIProvider simpleTokenURIProvider;
    address appLock;
    address accountLock;
    address feedLock;
    address graphLock;
    address groupLock;
    address namespaceLock;
    address accessControlLock;

    address proxyAdminLockOwner = vm.envOr("PROXY_ADMIN_LOCK_OWNER", makeAddr("PROXY_ADMIN_LOCK_OWNER"));
    address accessControlLockOwner = vm.envOr("ACCESS_CONTROL_LOCK_OWNER", makeAddr("ACCESS_CONTROL_LOCK_OWNER"));
    address rulesOwner = vm.envOr("RULES_OWNER", makeAddr("RULES_OWNER"));
    address actionsOwner = vm.envOr("ACTIONS_OWNER", makeAddr("ACTIONS_OWNER"));
    address beaconOwner = vm.envOr("BEACON_OWNER", makeAddr("BEACON_OWNER"));
    address factoriesProxyOwner = vm.envOr("FACTORIES_PROXY_OWNER", makeAddr("FACTORIES_PROXY_OWNER"));
    address rulesProxyOwner = vm.envOr("RULES_PROXY_OWNER", makeAddr("RULES_PROXY_OWNER"));
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

    address accessControlFactoryImpl;
    address accountFactoryImpl;
    address appFactoryImpl;
    address feedFactoryImpl;
    address graphFactoryImpl;
    address groupFactoryImpl;
    address namespaceFactoryImpl;

    address accountBlockingRule;
    address groupGatedFeedRule;
    address usernameSimpleCharsetRule;
    address banMemberGroupRule;
    address addRemovePidGroupRule;
    address usernameReservedNamespaceRule;

    function setUp() public virtual {
        if (isFork()) {
            _loadAddressBookJson();
            _loadFromFork();
        } else {
            _deployNewContracts();
        }
    }

    function _loadFromFork() internal {
        appLock = json.readAddress(".AppLock.address");
        accountLock = json.readAddress(".AccountLock.address");
        feedLock = json.readAddress(".FeedLock.address");
        graphLock = json.readAddress(".GraphLock.address");
        groupLock = json.readAddress(".GroupLock.address");
        namespaceLock = json.readAddress(".NamespaceLock.address");
        accessControlLock = json.readAddress(".AccessControlLock.address");

        _loadImplementations();
        _loadBeacons();
        _loadFactoryImplementations();
        _loadFactoryProxies();

        accountBlockingRule = json.readAddress(".AccountBlockingRule.address");
        groupGatedFeedRule = json.readAddress(".GroupGatedFeedRule.address");
        usernameSimpleCharsetRule = json.readAddress(".UsernameSimpleCharsetNamespaceRule.address");
        banMemberGroupRule = json.readAddress(".BanMemberGroupRule.address");
        addRemovePidGroupRule = json.readAddress(".AdditionRemovalPidGroupRule.address");
        usernameReservedNamespaceRule = json.readAddress(".UsernameReservedNamespaceRule.address");
        lensFactory = LensFactory(json.readAddress(".LensFactory.address"));
    }

    function _deployNewContracts() internal {
        appLock = address(new Lock(proxyAdminLockOwner, true));
        accountLock = address(new Lock(proxyAdminLockOwner, true));
        feedLock = address(new Lock(proxyAdminLockOwner, true));
        graphLock = address(new Lock(proxyAdminLockOwner, true));
        groupLock = address(new Lock(proxyAdminLockOwner, true));
        namespaceLock = address(new Lock(proxyAdminLockOwner, true));
        accessControlLock = address(new Lock(accessControlLockOwner, true));
        _deployImplementations();
        _deployBeacons();
        _deployFactoryImplementations(); // We have to do that because ERC1967 doesn't like address(0) as implementation
        _deployFactoryProxies();

        accountBlockingRule = address(
            new TransparentUpgradeableProxy(
                address(new AccountBlockingRule()),
                rulesProxyOwner,
                abi.encodeWithSelector(AccountBlockingRule.initialize.selector, rulesOwner, "uri://AccountBlockingRule")
            )
        );
        groupGatedFeedRule = address(
            new TransparentUpgradeableProxy(
                address(new GroupGatedFeedRule()),
                rulesProxyOwner,
                abi.encodeWithSelector(GroupGatedFeedRule.initialize.selector, rulesOwner, "uri://GroupGatedFeedRule")
            )
        );
        usernameSimpleCharsetRule = address(
            new TransparentUpgradeableProxy(
                address(new UsernameSimpleCharsetNamespaceRule()),
                rulesProxyOwner,
                abi.encodeWithSelector(
                    UsernameSimpleCharsetNamespaceRule.initialize.selector,
                    rulesOwner,
                    "uri://UsernameSimpleCharsetNamespaceRule"
                )
            )
        );
        banMemberGroupRule = address(
            new TransparentUpgradeableProxy(
                address(new BanMemberGroupRule()),
                rulesProxyOwner,
                abi.encodeWithSelector(BanMemberGroupRule.initialize.selector, rulesOwner, "uri://BanMemberGroupRule")
            )
        );
        addRemovePidGroupRule = address(
            new TransparentUpgradeableProxy(
                address(new AdditionRemovalPidGroupRule()),
                rulesProxyOwner,
                abi.encodeWithSelector(
                    AdditionRemovalPidGroupRule.initialize.selector, rulesOwner, "uri://AdditionRemovalPidGroupRule"
                )
            )
        );
        usernameReservedNamespaceRule = address(
            new TransparentUpgradeableProxy(
                address(new UsernameReservedNamespaceRule()),
                rulesProxyOwner,
                abi.encodeWithSelector(
                    UsernameReservedNamespaceRule.initialize.selector, rulesOwner, "uri://UsernameReservedNamespaceRule"
                )
            )
        );

        address lensFactoryImpl = address(
            new LensFactory({
                factories: FactoryConstructorParams({
                    accessControlFactory: accessControlFactory,
                    accountFactory: accountFactory,
                    appFactory: appFactory,
                    groupFactory: groupFactory,
                    feedFactory: feedFactory,
                    graphFactory: graphFactory,
                    namespaceFactory: namespaceFactory
                }),
                rules: RuleConstructorParams({
                    accountBlockingRule: accountBlockingRule,
                    groupGatedFeedRule: groupGatedFeedRule,
                    usernameSimpleCharsetRule: usernameSimpleCharsetRule,
                    banMemberGroupRule: banMemberGroupRule,
                    addRemovePidGroupRule: addRemovePidGroupRule,
                    usernameReservedNamespaceRule: usernameReservedNamespaceRule
                })
            })
        );
        TransparentUpgradeableProxy lensFactoryProxy =
            new TransparentUpgradeableProxy(address(lensFactoryImpl), factoriesProxyOwner, "");

        lensFactory = LensFactory(address(lensFactoryProxy));

        _deployFactoryImplementations();
        _setFactoryImplementationsToProxies();
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

    function _loadImplementations() internal {
        simpleAccessControl = IAccessControl(new RoleBasedAccessControl({owner: address(this)}));
        simpleTokenURIProvider = new LensUsernameTokenURIProvider();

        appImpl = json.readAddress(".AppImpl.address");
        accountImpl = json.readAddress(".AccountImpl.address");
        feedImpl = json.readAddress(".FeedImpl.address");
        graphImpl = json.readAddress(".GraphImpl.address");
        groupImpl = json.readAddress(".GroupImpl.address");
        namespaceImpl = json.readAddress(".NamespaceImpl.address");
    }

    function _deployBeacons() internal {
        appBeacon = address(new Beacon(beaconOwner, 1, appImpl));
        accountBeacon = address(new Beacon(beaconOwner, 1, accountImpl));
        feedBeacon = address(new Beacon(beaconOwner, 1, feedImpl));
        graphBeacon = address(new Beacon(beaconOwner, 1, graphImpl));
        groupBeacon = address(new Beacon(beaconOwner, 1, groupImpl));
        namespaceBeacon = address(new Beacon(beaconOwner, 1, namespaceImpl));
    }

    function _loadBeacons() internal {
        appBeacon = json.readAddress(".AppBeacon.address");
        accountBeacon = json.readAddress(".AccountBeacon.address");
        feedBeacon = json.readAddress(".FeedBeacon.address");
        graphBeacon = json.readAddress(".GraphBeacon.address");
        groupBeacon = json.readAddress(".GroupBeacon.address");
        namespaceBeacon = json.readAddress(".NamespaceBeacon.address");
    }

    function _deployFactoryImplementations() internal {
        accessControlFactoryImpl = address(new AccessControlFactory(accessControlLock));

        accountFactoryImpl = address(new AccountFactory(accountBeacon, accountLock));

        appFactoryImpl = address(new AppFactory(appBeacon, appLock));

        feedFactoryImpl = address(new FeedFactory(feedBeacon, feedLock, address(lensFactory)));

        graphFactoryImpl = address(new GraphFactory(graphBeacon, graphLock, address(lensFactory)));

        groupFactoryImpl = address(new GroupFactory(groupBeacon, groupLock, address(lensFactory)));

        namespaceFactoryImpl = address(new NamespaceFactory(namespaceBeacon, namespaceLock, address(lensFactory)));
    }

    function _loadFactoryImplementations() internal {
        accessControlFactoryImpl = json.readAddress(".AccessControlFactoryImpl.address");
        accountFactoryImpl = json.readAddress(".AccountFactoryImpl.address");
        appFactoryImpl = json.readAddress(".AppFactoryImpl.address");
        feedFactoryImpl = json.readAddress(".FeedFactoryImpl.address");
        graphFactoryImpl = json.readAddress(".GraphFactoryImpl.address");
        groupFactoryImpl = json.readAddress(".GroupFactoryImpl.address");
        namespaceFactoryImpl = json.readAddress(".NamespaceFactoryImpl.address");
    }

    function _deployFactoryProxies() internal {
        TransparentUpgradeableProxy accessControlFactoryProxy =
            new TransparentUpgradeableProxy(accessControlFactoryImpl, factoriesProxyOwner, "");
        accessControlFactory = AccessControlFactory(address(accessControlFactoryProxy));

        TransparentUpgradeableProxy accountFactoryProxy =
            new TransparentUpgradeableProxy(accountFactoryImpl, factoriesProxyOwner, "");
        accountFactory = AccountFactory(address(accountFactoryProxy));

        TransparentUpgradeableProxy appFactoryProxy =
            new TransparentUpgradeableProxy(appFactoryImpl, factoriesProxyOwner, "");
        appFactory = AppFactory(address(appFactoryProxy));

        TransparentUpgradeableProxy feedFactoryProxy =
            new TransparentUpgradeableProxy(address(feedFactoryImpl), factoriesProxyOwner, "");
        feedFactory = FeedFactory(address(feedFactoryProxy));

        TransparentUpgradeableProxy graphFactoryProxy =
            new TransparentUpgradeableProxy(graphFactoryImpl, factoriesProxyOwner, "");
        graphFactory = GraphFactory(address(graphFactoryProxy));

        TransparentUpgradeableProxy groupFactoryProxy =
            new TransparentUpgradeableProxy(groupFactoryImpl, factoriesProxyOwner, "");
        groupFactory = GroupFactory(address(groupFactoryProxy));

        TransparentUpgradeableProxy namespaceFactoryProxy =
            new TransparentUpgradeableProxy(namespaceFactoryImpl, factoriesProxyOwner, "");
        namespaceFactory = NamespaceFactory(address(namespaceFactoryProxy));
    }

    function _loadFactoryProxies() internal {
        accessControlFactory = AccessControlFactory(json.readAddress(".AccessControlFactory.address"));
        accountFactory = AccountFactory(json.readAddress(".AccountFactory.address"));
        appFactory = AppFactory(json.readAddress(".AppFactory.address"));
        feedFactory = FeedFactory(json.readAddress(".FeedFactory.address"));
        graphFactory = GraphFactory(json.readAddress(".GraphFactory.address"));
        groupFactory = GroupFactory(json.readAddress(".GroupFactory.address"));
        namespaceFactory = NamespaceFactory(json.readAddress(".NamespaceFactory.address"));
    }

    function _setFactoryImplementationsToProxies() internal {
        vm.startPrank(factoriesProxyOwner);
        ITransparentUpgradeableProxy(address(accessControlFactory)).upgradeTo(accessControlFactoryImpl);
        ITransparentUpgradeableProxy(address(appFactory)).upgradeTo(appFactoryImpl);
        ITransparentUpgradeableProxy(address(accountFactory)).upgradeTo(accountFactoryImpl);
        ITransparentUpgradeableProxy(address(feedFactory)).upgradeTo(feedFactoryImpl);
        ITransparentUpgradeableProxy(address(graphFactory)).upgradeTo(graphFactoryImpl);
        ITransparentUpgradeableProxy(address(groupFactory)).upgradeTo(groupFactoryImpl);
        ITransparentUpgradeableProxy(address(namespaceFactory)).upgradeTo(namespaceFactoryImpl);
        vm.stopPrank();
    }
}
