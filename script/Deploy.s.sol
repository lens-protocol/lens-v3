// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {ITokenURIProvider} from "contracts/core/interfaces/ITokenURIProvider.sol";

import {RoleBasedAccessControl} from "contracts/core/access/RoleBasedAccessControl.sol";
import {LensUsernameTokenURIProvider} from "contracts/core/primitives/namespace/LensUsernameTokenURIProvider.sol";

import {App} from "@extensions/primitives/app/App.sol";
import {Account} from "@extensions/account/Account.sol";
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

contract MyScript is Script {
    function testMyScript() public {
        // Prevents being counted in Foundry Coverage
    }

    IAccessControl simpleAccessControl;
    ITokenURIProvider simpleTokenURIProvider;
    address proxyAdminLock;
    address accessControlLock;
    address lockOwner = makeAddr("LOCK_OWNER");

    address proxyAdmin = makeAddr("PROXY_ADMIN");

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

    AccessControlFactory accessControlFactory;
    AppFactory appFactory;
    AccountFactory accountFactory;
    FeedFactory feedFactory;
    GraphFactory graphFactory;
    GroupFactory groupFactory;
    NamespaceFactory namespaceFactory;

    address accessControlFactoryImpl;
    address appFactoryImpl;
    address accountFactoryImpl;
    address feedFactoryImpl;
    address graphFactoryImpl;
    address groupFactoryImpl;
    address namespaceFactoryImpl;

    LensFactory lensFactory;

    address accountBlockingRule;
    address groupGatedFeedRule;
    address usernameSimpleCharsetRule;
    address banMemberGroupRule;
    address addRemovePidGroupRule;
    address usernameReservedNamespaceRule;

    function run() external {
        proxyAdminLock = address(new Lock(lockOwner, true));
        accessControlLock = address(new Lock(lockOwner, true));
        _deployImplementations();
        _deployBeacons();
        _deployFactoryImplementations(); // We have to do that because ERC1967 doesn't like address(0) as implementation
        _deployFactoryProxies();

        accountBlockingRule = address(
            new TransparentUpgradeableProxy(
                address(new AccountBlockingRule()),
                proxyAdmin,
                abi.encodeWithSelector(AccountBlockingRule.initialize.selector, address(this), "uri://any")
            )
        );
        groupGatedFeedRule = address(
            new TransparentUpgradeableProxy(
                address(new GroupGatedFeedRule()),
                proxyAdmin,
                abi.encodeWithSelector(GroupGatedFeedRule.initialize.selector, address(this), "uri://any")
            )
        );
        usernameSimpleCharsetRule = address(
            new TransparentUpgradeableProxy(
                address(new UsernameSimpleCharsetNamespaceRule()),
                proxyAdmin,
                abi.encodeWithSelector(
                    UsernameSimpleCharsetNamespaceRule.initialize.selector, address(this), "uri://any"
                )
            )
        );
        banMemberGroupRule = address(
            new TransparentUpgradeableProxy(
                address(new BanMemberGroupRule()),
                proxyAdmin,
                abi.encodeWithSelector(BanMemberGroupRule.initialize.selector, address(this), "uri://any")
            )
        );
        addRemovePidGroupRule = address(
            new TransparentUpgradeableProxy(
                address(new AdditionRemovalPidGroupRule()),
                proxyAdmin,
                abi.encodeWithSelector(AdditionRemovalPidGroupRule.initialize.selector, address(this), "uri://any")
            )
        );
        usernameReservedNamespaceRule = address(
            new TransparentUpgradeableProxy(
                address(new UsernameReservedNamespaceRule()),
                proxyAdmin,
                abi.encodeWithSelector(UsernameReservedNamespaceRule.initialize.selector, address(this), "uri://any")
            )
        );

        lensFactory = new LensFactory({
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
        });

        _deployFactoryImplementations();
        _setFactoryImplementationsToProxies();
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
        accountBeacon = address(new Beacon(lockOwner, 1, accountImpl));

        feedBeacon = address(new Beacon(lockOwner, 1, feedImpl));
        graphBeacon = address(new Beacon(lockOwner, 1, graphImpl));
        groupBeacon = address(new Beacon(lockOwner, 1, groupImpl));
        namespaceBeacon = address(new Beacon(lockOwner, 1, namespaceImpl));
    }

    function _deployFactoryImplementations() internal {
        accessControlFactoryImpl = address(new AccessControlFactory(accessControlLock));
        appFactoryImpl = address(new AppFactory(appBeacon, proxyAdminLock));
        accountFactoryImpl = address(new AccountFactory(accountBeacon, proxyAdminLock));
        feedFactoryImpl = address(new FeedFactory(feedBeacon, proxyAdminLock, address(lensFactory)));
        graphFactoryImpl = address(new GraphFactory(graphBeacon, proxyAdminLock, address(lensFactory)));
        groupFactoryImpl = address(new GroupFactory(groupBeacon, proxyAdminLock, address(lensFactory)));
        namespaceFactoryImpl = address(new NamespaceFactory(namespaceBeacon, proxyAdminLock, address(lensFactory)));
    }

    function _deployFactoryProxies() internal {
        accessControlFactory = AccessControlFactory(
            address(new TransparentUpgradeableProxy(address(accessControlFactoryImpl), proxyAdmin, ""))
        );
        appFactory = AppFactory(address(new TransparentUpgradeableProxy(address(appFactoryImpl), proxyAdmin, "")));
        accountFactory =
            AccountFactory(address(new TransparentUpgradeableProxy(address(accountFactoryImpl), proxyAdmin, "")));
        feedFactory = FeedFactory(address(new TransparentUpgradeableProxy(address(feedFactoryImpl), proxyAdmin, "")));
        graphFactory = GraphFactory(address(new TransparentUpgradeableProxy(address(graphFactoryImpl), proxyAdmin, "")));
        groupFactory = GroupFactory(address(new TransparentUpgradeableProxy(address(groupFactoryImpl), proxyAdmin, "")));
        namespaceFactory =
            NamespaceFactory(address(new TransparentUpgradeableProxy(address(namespaceFactoryImpl), proxyAdmin, "")));
    }

    function _setFactoryImplementationsToProxies() internal {
        vm.startPrank(proxyAdmin);
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
