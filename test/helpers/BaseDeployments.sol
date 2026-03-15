// SPDX-License-Identifier: GPL-3.0-only
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

import {CONTRACT__LENS_FEES, CONTRACT__LENS_NATIVE_PAYMENT_HELPER} from "contracts/core/types/Constants.sol";
import {LENS_CREATE_2_ADDRESS} from "contracts/core/upgradeability/LensCreate2.sol";

import {Lock} from "contracts/core/upgradeability/Lock.sol";
import {Beacon} from "contracts/core/upgradeability/Beacon.sol";

import {AccountBlockingRule} from "contracts/rules/AccountBlockingRule.sol";
import {GroupGatedFeedRule} from "contracts/rules/feed/GroupGatedFeedRule.sol";
import {UsernameSimpleCharsetNamespaceRule} from "contracts/rules/namespace/UsernameSimpleCharsetNamespaceRule.sol";
import {BanMemberGroupRule} from "contracts/rules/group/BanMemberGroupRule.sol";
import {AdditionRemovalPidGroupRule} from "contracts/rules/group/AdditionRemovalPidGroupRule.sol";
import {UsernameReservedNamespaceRule} from "contracts/rules/namespace/UsernameReservedNamespaceRule.sol";
import {WhitelistedSignersNamespaceRule} from "contracts/rules/namespace/WhitelistedSignersNamespaceRule.sol";

import {TippingAccountAction} from "contracts/actions/account/TippingAccountAction.sol";
import {TippingPostAction} from "contracts/actions/post/TippingPostAction.sol";
import {SimpleCollectAction} from "contracts/actions/post/collect/SimpleCollectAction.sol";

import {LensFees} from "contracts/extensions/fees/LensFees.sol";

import {MockCurrency} from "test/mocks/MockCurrency.sol";
import {MockWrapperCurrency} from "test/mocks/MockWrapperCurrency.sol";
import {MockNft} from "test/mocks/MockNft.sol";

import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ZkTest} from "test/helpers/ZkTest.sol";

import {MockLensCreate2} from "test/mocks/MockLensCreate2.sol";
import {EmptyImplementation} from "@core/upgradeability/EmptyImplementation.sol";
import {LensNativePaymentHelper} from "@extensions/fees/LensNativePaymentHelper.sol";

contract BaseDeployments is ZkTest {
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
    address lensCreate2ProxyAdmin = vm.envOr("LENS_CREATE_2_PROXY_ADMIN", makeAddr("LENS_CREATE_2_PROXY_ADMIN"));

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
    address payable lensNativePaymentHelper;

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
    address whitelistedSignersNamespaceRule;

    address tippingAccountActionImpl;
    address tippingAccountAction;

    address tippingPostActionImpl;
    address tippingPostAction;

    address simpleCollectActionImpl;
    address simpleCollectAction;

    address TREASURY_ADDRESS = vm.envOr("TREASURY_ADDRESS", makeAddr("TREASURY_ADDRESS"));
    uint16 TREASURY_FEE_BPS = uint16(vm.envOr("TREASURY_FEE_BPS", uint256(150)));

    address GHO = address(0x800A);
    MockWrapperCurrency WGHO;
    MockCurrency someCurrency;
    MockNft someNft;

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
        address emptyImpl = address(new EmptyImplementation());
        new TransparentUpgradeableProxy(emptyImpl, emptyImpl, ""); // Discarded, just to avoid UnknownCodeHash error

        // "TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy" deployed bytecode
        bytes memory proxyDeployedEVMCode =
            hex"6080604052366100135761001161001d565b005b61001b61001d565b005b610025610299565b73ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff160361028f576060600080357fffffffff00000000000000000000000000000000000000000000000000000000169050633659cfe660e01b7bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916817bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916036100dc576100d56102f0565b9150610287565b634f1ef28660e01b7bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916817bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916036101375761013061034f565b9150610286565b638f28397060e01b7bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916817bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916036101925761018b61039c565b9150610285565b63f851a44060e01b7bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916817bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916036101ed576101e66103e9565b9150610284565b635c60da1b60e01b7bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916817bffffffffffffffffffffffffffffffffffffffffffffffffffffffff19160361024857610241610425565b9150610283565b6040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161027a906109c6565b60405180910390fd5b5b5b5b5b815160208301f35b610297610461565b565b60006102c77fb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d610360001b61047b565b60000160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff16905090565b60606102fa610485565b60008036600490809261030f939291906109fa565b81019061031c9190610a9d565b905061033981604051806020016040528060008152506000610494565b6040518060200160405280600081525091505090565b60606000806000366004908092610368939291906109fa565b8101906103759190610c10565b9150915061038582826001610494565b604051806020016040528060008152509250505090565b60606103a6610485565b6000803660049080926103bb939291906109fa565b8101906103c89190610a9d565b90506103d3816104c0565b6040518060200160405280600081525091505090565b60606103f3610485565b60006103fd610299565b9050806040516020016104109190610c8d565b60405160208183030381529060405291505090565b606061042f610485565b600061043961050c565b90508060405160200161044c9190610c8d565b60405160208183030381529060405291505090565b61046961051b565b61047961047461050c565b61051d565b565b6000819050919050565b6000341461049257600080fd5b565b61049d83610543565b6000825111806104aa5750805b156104bb576104b98383610592565b505b505050565b7f7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f6104e9610299565b826040516104f8929190610ca8565b60405180910390a1610509816105bf565b50565b600061051661069f565b905090565b565b3660008037600080366000845af43d6000803e806000811461053e573d6000f35b3d6000fd5b61054c816106f6565b8073ffffffffffffffffffffffffffffffffffffffff167fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b60405160405180910390a250565b60606105b78383604051806060016040528060278152602001610f50602791396107af565b905092915050565b600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff160361062e576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161062590610d43565b60405180910390fd5b8061065b7fb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d610360001b61047b565b60000160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555050565b60006106cd7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc60001b61047b565b60000160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff16905090565b6106ff81610835565b61073e576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161073590610dd5565b60405180910390fd5b8061076b7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc60001b61047b565b60000160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555050565b60606000808573ffffffffffffffffffffffffffffffffffffffff16856040516107d99190610e66565b600060405180830381855af49150503d8060008114610814576040519150601f19603f3d011682016040523d82523d6000602084013e610819565b606091505b509150915061082a86838387610858565b925050509392505050565b6000808273ffffffffffffffffffffffffffffffffffffffff163b119050919050565b606083156108ba5760008351036108b25761087285610835565b6108b1576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016108a890610ec9565b60405180910390fd5b5b8290506108c5565b6108c483836108cd565b5b949350505050565b6000825111156108e05781518083602001fd5b806040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016109149190610f2d565b60405180910390fd5b600082825260208201905092915050565b7f5472616e73706172656e745570677261646561626c6550726f78793a2061646d60008201527f696e2063616e6e6f742066616c6c6261636b20746f2070726f7879207461726760208201527f6574000000000000000000000000000000000000000000000000000000000000604082015250565b60006109b060428361091d565b91506109bb8261092e565b606082019050919050565b600060208201905081810360008301526109df816109a3565b9050919050565b6000604051905090565b600080fd5b600080fd5b60008085851115610a0e57610a0d6109f0565b5b83861115610a1f57610a1e6109f5565b5b6001850283019150848603905094509492505050565b600080fd5b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b6000610a6a82610a3f565b9050919050565b610a7a81610a5f565b8114610a8557600080fd5b50565b600081359050610a9781610a71565b92915050565b600060208284031215610ab357610ab2610a35565b5b6000610ac184828501610a88565b91505092915050565b600080fd5b600080fd5b6000601f19601f8301169050919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b610b1d82610ad4565b810181811067ffffffffffffffff82111715610b3c57610b3b610ae5565b5b80604052505050565b6000610b4f6109e6565b9050610b5b8282610b14565b919050565b600067ffffffffffffffff821115610b7b57610b7a610ae5565b5b610b8482610ad4565b9050602081019050919050565b82818337600083830152505050565b6000610bb3610bae84610b60565b610b45565b905082815260208101848484011115610bcf57610bce610acf565b5b610bda848285610b91565b509392505050565b600082601f830112610bf757610bf6610aca565b5b8135610c07848260208601610ba0565b91505092915050565b60008060408385031215610c2757610c26610a35565b5b6000610c3585828601610a88565b925050602083013567ffffffffffffffff811115610c5657610c55610a3a565b5b610c6285828601610be2565b9150509250929050565b6000610c7782610a3f565b9050919050565b610c8781610c6c565b82525050565b6000602082019050610ca26000830184610c7e565b92915050565b6000604082019050610cbd6000830185610c7e565b610cca6020830184610c7e565b9392505050565b7f455243313936373a206e65772061646d696e20697320746865207a65726f206160008201527f6464726573730000000000000000000000000000000000000000000000000000602082015250565b6000610d2d60268361091d565b9150610d3882610cd1565b604082019050919050565b60006020820190508181036000830152610d5c81610d20565b9050919050565b7f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60008201527f6f74206120636f6e747261637400000000000000000000000000000000000000602082015250565b6000610dbf602d8361091d565b9150610dca82610d63565b604082019050919050565b60006020820190508181036000830152610dee81610db2565b9050919050565b600081519050919050565b600081905092915050565b60005b83811015610e29578082015181840152602081019050610e0e565b60008484015250505050565b6000610e4082610df5565b610e4a8185610e00565b9350610e5a818560208601610e0b565b80840191505092915050565b6000610e728284610e35565b915081905092915050565b7f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000600082015250565b6000610eb3601d8361091d565b9150610ebe82610e7d565b602082019050919050565b60006020820190508181036000830152610ee281610ea6565b9050919050565b600081519050919050565b6000610eff82610ee9565b610f09818561091d565b9350610f19818560208601610e0b565b610f2281610ad4565b840191505092915050565b60006020820190508181036000830152610f478184610ef4565b90509291505056fe416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a2646970667358221220ac187be4350f48ff40de1a430a5ff1251d6b0f2939c94cc54f1a5f8ef792ad7664736f6c634300081c003300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        // Super nasty hack to make this compile and work in both ZkSync and native EVM.
        // We need to do that because:
        // - getCode doesn't work in native EVM (contains constructor code, we need getDeployedCode instead)
        // - getDeployedCode doesn't work in ZkSync (fails with an error about multiple artifacts during compilation)
        vm.etch(
            LENS_CREATE_2_ADDRESS,
            isZkEvm() ? vm.getCode("TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy") : proxyDeployedEVMCode
        );

        MockLensCreate2 create2Impl = new MockLensCreate2();

        vm.store(
            LENS_CREATE_2_ADDRESS,
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
            bytes32(uint256(uint160(address(create2Impl))))
        );
        vm.store(
            LENS_CREATE_2_ADDRESS,
            0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103, // bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
            bytes32(uint256(uint160(lensCreate2ProxyAdmin)))
        );

        MockLensCreate2(LENS_CREATE_2_ADDRESS).setAddress(CONTRACT__LENS_FEES, makeAddr("LENS_FEES"));
        address lensFeesAddress = MockLensCreate2(LENS_CREATE_2_ADDRESS).getAddress(CONTRACT__LENS_FEES);
        assertEq(lensFeesAddress, makeAddr("LENS_FEES"), "[LENS_CREATE_2] LensFees address is not set correctly");
    }

    function _loadFromFork() internal {
        // LOG: console.log("Loading from fork");
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
        whitelistedSignersNamespaceRule = json.readAddress(".WhitelistedSignersNamespaceRule.address");
        lensFactory = LensFactory(json.readAddress(".LensFactory.address"));
    }

    function _deployNewContracts() internal {
        // LOG: console.log("Deploying new contracts");
        appLock = address(new Lock(proxyAdminLockOwner, true));
        accountLock = address(new Lock(proxyAdminLockOwner, true));
        feedLock = address(new Lock(proxyAdminLockOwner, true));
        graphLock = address(new Lock(proxyAdminLockOwner, true));
        groupLock = address(new Lock(proxyAdminLockOwner, true));
        namespaceLock = address(new Lock(proxyAdminLockOwner, true));
        accessControlLock = address(new Lock(accessControlLockOwner, true));

        WGHO = new MockWrapperCurrency("Wrapped GHO", "WGHO");
        someCurrency = new MockCurrency("Aave", "AAVE");
        someNft = new MockNft("Milady Maker", "MIL");

        actionHubImpl = address(new ActionHub());
        actionHub = address(new TransparentUpgradeableProxy(actionHubImpl, factoriesProxyOwner, ""));

        lensFeesImpl = address(new LensFees(TREASURY_ADDRESS, TREASURY_FEE_BPS));
        lensFees = address(new TransparentUpgradeableProxy(lensFeesImpl, factoriesProxyOwner, ""));
        lensNativePaymentHelper = payable(new LensNativePaymentHelper());
        MockLensCreate2(LENS_CREATE_2_ADDRESS).setAddress(CONTRACT__LENS_NATIVE_PAYMENT_HELPER, lensNativePaymentHelper);
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
        whitelistedSignersNamespaceRule = address(
            new TransparentUpgradeableProxy(
                address(new WhitelistedSignersNamespaceRule()),
                rulesProxyOwner,
                abi.encodeWithSelector(
                    WhitelistedSignersNamespaceRule.initialize.selector,
                    rulesOwner,
                    "uri://WhitelistedSignersNamespaceRule"
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
        // LOG: console.log("Finished deploying new contracts");
    }

    function _deployImplementations() internal {
        // LOG: console.log("Deploying implementations");
        simpleAccessControl = IAccessControl(new RoleBasedAccessControl({owner: address(this)}));
        simpleTokenURIProvider = new LensUsernameTokenURIProvider();

        appImpl = address(new App());
        accountImpl = address(new AccountContract({nativeGHO: address(GHO), wrappedGHO: address(WGHO)}));
        feedImpl = address(new Feed());
        graphImpl = address(new Graph());
        groupImpl = address(new Group());
        namespaceImpl = address(new Namespace());
    }

    function _loadImplementations() internal {
        // LOG: console.log("Loading implementations");
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
        // LOG: console.log("Deploying actions");
        tippingAccountActionImpl = address(new TippingAccountAction(actionHub));
        tippingAccountAction =
            address(new TransparentUpgradeableProxy(tippingAccountActionImpl, factoriesProxyOwner, ""));

        tippingPostActionImpl = address(new TippingPostAction(actionHub));
        tippingPostAction = address(new TransparentUpgradeableProxy(tippingPostActionImpl, factoriesProxyOwner, ""));

        simpleCollectActionImpl = address(new SimpleCollectAction(actionHub));
        simpleCollectAction = address(new TransparentUpgradeableProxy(simpleCollectActionImpl, factoriesProxyOwner, ""));
    }

    function _loadActions() internal {
        // LOG: console.log("Loading actions");
        tippingAccountActionImpl = json.readAddress(".TippingAccountActionImpl.address");
        tippingAccountAction = json.readAddress(".TippingAccountAction.address");

        tippingPostActionImpl = json.readAddress(".TippingPostActionImpl.address");
        tippingPostAction = json.readAddress(".TippingPostAction.address");

        simpleCollectActionImpl = json.readAddress(".SimpleCollectActionImpl.address");
        simpleCollectAction = json.readAddress(".SimpleCollectAction.address");
    }

    function _deployBeacons() internal {
        // LOG: console.log("Deploying beacons");
        appBeacon = address(new Beacon(beaconOwner, 1, appImpl));
        accountBeacon = address(new Beacon(beaconOwner, 1, accountImpl));
        feedBeacon = address(new Beacon(beaconOwner, 1, feedImpl));
        graphBeacon = address(new Beacon(beaconOwner, 1, graphImpl));
        groupBeacon = address(new Beacon(beaconOwner, 1, groupImpl));
        namespaceBeacon = address(new Beacon(beaconOwner, 1, namespaceImpl));
    }

    function _loadBeacons() internal {
        // LOG: console.log("Loading beacons");
        appBeacon = json.readAddress(".AppBeacon.address");
        accountBeacon = json.readAddress(".AccountBeacon.address");
        feedBeacon = json.readAddress(".FeedBeacon.address");
        graphBeacon = json.readAddress(".GraphBeacon.address");
        groupBeacon = json.readAddress(".GroupBeacon.address");
        namespaceBeacon = json.readAddress(".NamespaceBeacon.address");
    }

    function _deployFactoryImplementations() internal {
        // LOG: console.log("Deploying factory implementations");
        accessControlFactoryImpl = address(new AccessControlFactory(accessControlLock));

        accountFactoryImpl = address(new AccountFactory(accountBeacon, accountLock));

        appFactoryImpl = address(new AppFactory(appBeacon, appLock));

        feedFactoryImpl = address(new FeedFactory(feedBeacon, feedLock, address(lensFactory)));

        graphFactoryImpl = address(new GraphFactory(graphBeacon, graphLock, address(lensFactory)));

        groupFactoryImpl = address(new GroupFactory(groupBeacon, groupLock, address(lensFactory)));

        namespaceFactoryImpl = address(new NamespaceFactory(namespaceBeacon, namespaceLock, address(lensFactory)));
    }

    function _loadFactoryImplementations() internal {
        // LOG: console.log("Loading factory implementations");
        accessControlFactoryImpl = json.readAddress(".AccessControlFactoryImpl.address");
        accountFactoryImpl = json.readAddress(".AccountFactoryImpl.address");
        appFactoryImpl = json.readAddress(".AppFactoryImpl.address");
        feedFactoryImpl = json.readAddress(".FeedFactoryImpl.address");
        graphFactoryImpl = json.readAddress(".GraphFactoryImpl.address");
        groupFactoryImpl = json.readAddress(".GroupFactoryImpl.address");
        namespaceFactoryImpl = json.readAddress(".NamespaceFactoryImpl.address");
    }

    function _deployFactoryProxies() internal {
        // LOG: console.log("Deploying factory proxies");
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
        // LOG: console.log("Loading factory proxies");
        accessControlFactory = AccessControlFactory(json.readAddress(".AccessControlFactory.address"));
        accountFactory = AccountFactory(json.readAddress(".AccountFactory.address"));
        appFactory = AppFactory(json.readAddress(".AppFactory.address"));
        feedFactory = FeedFactory(json.readAddress(".FeedFactory.address"));
        graphFactory = GraphFactory(json.readAddress(".GraphFactory.address"));
        groupFactory = GroupFactory(json.readAddress(".GroupFactory.address"));
        namespaceFactory = NamespaceFactory(json.readAddress(".NamespaceFactory.address"));
    }

    function _setFactoryImplementationsToProxies() internal {
        // LOG: console.log("Setting factory implementations to proxies");
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
