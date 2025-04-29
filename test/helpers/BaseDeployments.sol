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

import {ActionHub} from "@extensions/actions/ActionHub.sol";

import {AccessControlFactory} from "@extensions/factories/AccessControlFactory.sol";
import {AccountFactory} from "@extensions/factories/AccountFactory.sol";

import {AppFactory} from "@extensions/factories/AppFactory.sol";
import {FeedFactory} from "@extensions/factories/FeedFactory.sol";
import {GraphFactory} from "@extensions/factories/GraphFactory.sol";
import {GroupFactory} from "@extensions/factories/GroupFactory.sol";
import {NamespaceFactory} from "@extensions/factories/NamespaceFactory.sol";
import {LensFactory, FactoryConstructorParams, RuleConstructorParams} from "@extensions/factories/LensFactory.sol";

import {CONTRACT__LENS_FEES} from "contracts/core/types/Constants.sol";
import {LENS_CREATE_2_ADDRESS} from "contracts/core/upgradeability/LensCreate2.sol";

import {Lock} from "contracts/core/upgradeability/Lock.sol";
import {Beacon} from "contracts/core/upgradeability/Beacon.sol";

import {AccountBlockingRule} from "contracts/rules/AccountBlockingRule.sol";
import {GroupGatedFeedRule} from "contracts/rules/feed/GroupGatedFeedRule.sol";
import {UsernameSimpleCharsetNamespaceRule} from "contracts/rules/namespace/UsernameSimpleCharsetNamespaceRule.sol";
import {BanMemberGroupRule} from "contracts/rules/group/BanMemberGroupRule.sol";
import {AdditionRemovalPidGroupRule} from "contracts/rules/group/AdditionRemovalPidGroupRule.sol";
import {UsernameReservedNamespaceRule} from "contracts/rules/namespace/UsernameReservedNamespaceRule.sol";

import {TippingAccountAction} from "contracts/actions/account/TippingAccountAction.sol";

import {LensFees} from "contracts/extensions/fees/LensFees.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ZkTester} from "test/helpers/ZkTest.sol";

contract MockLensCreate2 {
    mapping(bytes32 => address) public addresses;

    function getAddress(bytes32 salt) public view returns (address) {
        return addresses[salt];
    }

    function setAddress(bytes32 salt, address addr) public {
        addresses[salt] = addr;
    }
}

contract BaseDeployments is Test, ZkTester {
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
    address actionHubImpl;

    address appBeacon;
    address accountBeacon;
    address feedBeacon;
    address graphBeacon;
    address groupBeacon;
    address namespaceBeacon;

    address actionHub;

    address lensFeesImpl;
    address lensFees;

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

    address tippingAccountActionImpl;
    address tippingAccountAction;

    address TREASURY_ADDRESS = makeAddr("TREASURY_ADDRESS");
    uint16 TREASURY_FEE_BPS = 150;

    function setUp() public virtual {
        if (isFork()) {
            _loadAddressBookJson();
            _loadFromFork();
        } else {
            _deployMockLensCreate2();
            _deployNewContracts();
        }
    }

    function _deployMockLensCreate2() internal {
        console.log("Deploying mock LensCreate2");

        // TODO: This doesn't work with --zksync tests (Multiple artifacts found), only getCode() works
        vm.etch(LENS_CREATE_2_ADDRESS, vm.getDeployedCode("test/helpers/BaseDeployments.sol:MockLensCreate2"));
        // TODO: But on the other hand, getCode() doesn't work with native foundry tests...
        // vm.etch(LENS_CREATE_2_ADDRESS, vm.getCode("test/helpers/BaseDeployments.sol:MockLensCreate2"));
        // TODO: So you kinda cannot auto-test both lol :) Uncomment one line above and comment the other to switch.

        console.log("Mock LensCreate2 deployed. Trying...");
        MockLensCreate2(LENS_CREATE_2_ADDRESS).setAddress(CONTRACT__LENS_FEES, makeAddr("LENS_FEES"));
        console.log("Mock LensCreate2 set address");
        address lensFeesAddress = MockLensCreate2(LENS_CREATE_2_ADDRESS).getAddress(CONTRACT__LENS_FEES);
        console.log("lensFeesAddress is", lensFeesAddress);
    }

    function _loadFromFork() internal {
        // TODO: Load TREASURY_ADDRESS and TREASURY_FEE_BPS from addressBook.json

        console.log("Loading from fork");
        appLock = json.readAddress(".AppLock.address");
        accountLock = json.readAddress(".AccountLock.address");
        feedLock = json.readAddress(".FeedLock.address");
        graphLock = json.readAddress(".GraphLock.address");
        groupLock = json.readAddress(".GroupLock.address");
        namespaceLock = json.readAddress(".NamespaceLock.address");
        accessControlLock = json.readAddress(".AccessControlLock.address");

        actionHubImpl = json.readAddress(".ActionHubImpl.address");
        actionHub = json.readAddress(".ActionHub.address");

        _loadImplementations();
        _loadBeacons();
        _loadFactoryImplementations();
        _loadFactoryProxies();
        _loadActions();

        accountBlockingRule = json.readAddress(".AccountBlockingRule.address");
        groupGatedFeedRule = json.readAddress(".GroupGatedFeedRule.address");
        usernameSimpleCharsetRule = json.readAddress(".UsernameSimpleCharsetNamespaceRule.address");
        banMemberGroupRule = json.readAddress(".BanMemberGroupRule.address");
        addRemovePidGroupRule = json.readAddress(".AdditionRemovalPidGroupRule.address");
        usernameReservedNamespaceRule = json.readAddress(".UsernameReservedNamespaceRule.address");
        lensFactory = LensFactory(json.readAddress(".LensFactory.address"));
    }

    function _deployNewContracts() internal {
        console.log("Deploying new contracts");
        appLock = address(new Lock(proxyAdminLockOwner, true));
        accountLock = address(new Lock(proxyAdminLockOwner, true));
        feedLock = address(new Lock(proxyAdminLockOwner, true));
        graphLock = address(new Lock(proxyAdminLockOwner, true));
        groupLock = address(new Lock(proxyAdminLockOwner, true));
        namespaceLock = address(new Lock(proxyAdminLockOwner, true));
        accessControlLock = address(new Lock(accessControlLockOwner, true));

        actionHubImpl = address(new ActionHub());
        actionHub = address(new TransparentUpgradeableProxy(actionHubImpl, factoriesProxyOwner, ""));

        lensFeesImpl = address(new LensFees(TREASURY_ADDRESS, TREASURY_FEE_BPS));
        lensFees = address(new TransparentUpgradeableProxy(lensFeesImpl, factoriesProxyOwner, ""));
        MockLensCreate2(LENS_CREATE_2_ADDRESS).setAddress(CONTRACT__LENS_FEES, lensFees);

        _deployImplementations();
        _deployBeacons();
        _deployFactoryImplementations(); // We have to do that because ERC1967 doesn't like address(0) as implementation
        _deployFactoryProxies();

        _deployActions();

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
        console.log("Finished deploying new contracts");
    }

    function _deployImplementations() internal {
        console.log("Deploying implementations");
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
        console.log("Loading implementations");
        simpleAccessControl = IAccessControl(new RoleBasedAccessControl({owner: address(this)}));
        simpleTokenURIProvider = new LensUsernameTokenURIProvider();

        appImpl = json.readAddress(".AppImpl.address");
        accountImpl = json.readAddress(".AccountImpl.address");
        feedImpl = json.readAddress(".FeedImpl.address");
        graphImpl = json.readAddress(".GraphImpl.address");
        groupImpl = json.readAddress(".GroupImpl.address");
        namespaceImpl = json.readAddress(".NamespaceImpl.address");
    }

    function _deployActions() internal {
        console.log("Deploying actions");
        tippingAccountActionImpl = address(new TippingAccountAction(actionHub));
        tippingAccountAction =
            address(new TransparentUpgradeableProxy(tippingAccountActionImpl, factoriesProxyOwner, ""));
    }

    function _loadActions() internal {
        console.log("Loading actions");
        tippingAccountActionImpl = json.readAddress(".TippingAccountActionImpl.address");
        tippingAccountAction = json.readAddress(".TippingAccountAction.address");
    }

    function _deployBeacons() internal {
        console.log("Deploying beacons");
        appBeacon = address(new Beacon(beaconOwner, 1, appImpl));
        accountBeacon = address(new Beacon(beaconOwner, 1, accountImpl));
        feedBeacon = address(new Beacon(beaconOwner, 1, feedImpl));
        graphBeacon = address(new Beacon(beaconOwner, 1, graphImpl));
        groupBeacon = address(new Beacon(beaconOwner, 1, groupImpl));
        namespaceBeacon = address(new Beacon(beaconOwner, 1, namespaceImpl));
    }

    function _loadBeacons() internal {
        console.log("Loading beacons");
        appBeacon = json.readAddress(".AppBeacon.address");
        accountBeacon = json.readAddress(".AccountBeacon.address");
        feedBeacon = json.readAddress(".FeedBeacon.address");
        graphBeacon = json.readAddress(".GraphBeacon.address");
        groupBeacon = json.readAddress(".GroupBeacon.address");
        namespaceBeacon = json.readAddress(".NamespaceBeacon.address");
    }

    function _deployFactoryImplementations() internal {
        console.log("Deploying factory implementations");
        accessControlFactoryImpl = address(new AccessControlFactory(accessControlLock));

        accountFactoryImpl = address(new AccountFactory(accountBeacon, accountLock));

        appFactoryImpl = address(new AppFactory(appBeacon, appLock));

        feedFactoryImpl = address(new FeedFactory(feedBeacon, feedLock, address(lensFactory)));

        graphFactoryImpl = address(new GraphFactory(graphBeacon, graphLock, address(lensFactory)));

        groupFactoryImpl = address(new GroupFactory(groupBeacon, groupLock, address(lensFactory)));

        namespaceFactoryImpl = address(new NamespaceFactory(namespaceBeacon, namespaceLock, address(lensFactory)));
    }

    function _loadFactoryImplementations() internal {
        console.log("Loading factory implementations");
        accessControlFactoryImpl = json.readAddress(".AccessControlFactoryImpl.address");
        accountFactoryImpl = json.readAddress(".AccountFactoryImpl.address");
        appFactoryImpl = json.readAddress(".AppFactoryImpl.address");
        feedFactoryImpl = json.readAddress(".FeedFactoryImpl.address");
        graphFactoryImpl = json.readAddress(".GraphFactoryImpl.address");
        groupFactoryImpl = json.readAddress(".GroupFactoryImpl.address");
        namespaceFactoryImpl = json.readAddress(".NamespaceFactoryImpl.address");
    }

    function _deployFactoryProxies() internal {
        console.log("Deploying factory proxies");
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
        console.log("Loading factory proxies");
        accessControlFactory = AccessControlFactory(json.readAddress(".AccessControlFactory.address"));
        accountFactory = AccountFactory(json.readAddress(".AccountFactory.address"));
        appFactory = AppFactory(json.readAddress(".AppFactory.address"));
        feedFactory = FeedFactory(json.readAddress(".FeedFactory.address"));
        graphFactory = GraphFactory(json.readAddress(".GraphFactory.address"));
        groupFactory = GroupFactory(json.readAddress(".GroupFactory.address"));
        namespaceFactory = NamespaceFactory(json.readAddress(".NamespaceFactory.address"));
    }

    function _setFactoryImplementationsToProxies() internal {
        console.log("Setting factory implementations to proxies");
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
