// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRoleBasedAccessControl} from "./../primitives/access-control/IRoleBasedAccessControl.sol";
import {IAccessControl} from "./../primitives/access-control/IAccessControl.sol";
import {Group} from "./../primitives/group/Group.sol";
import {RoleBasedAccessControl} from "./../primitives/access-control/RoleBasedAccessControl.sol";
import {RoleBasedAccessControl} from "./../primitives/access-control/RoleBasedAccessControl.sol";
import {RuleConfiguration, RuleExecutionData, DataElement} from "./../types/Types.sol";
import {GroupFactory} from "./GroupFactory.sol";
import {FeedFactory} from "./FeedFactory.sol";
import {GraphFactory} from "./GraphFactory.sol";
import {UsernameFactory} from "./UsernameFactory.sol";
import {AppFactory, AppInitialProperties} from "./AppFactory.sol";
import {AccountFactory} from "./AccountFactory.sol";
import {IAccount} from "./../primitives/account/IAccount.sol";
import {IUsername} from "./../primitives/username/IUsername.sol";
import {ITokenURIProvider} from "../primitives/base/ITokenURIProvider.sol";
import {LensUsernameTokenURIProvider} from "./../primitives/username/LensUsernameTokenURIProvider.sol";

// TODO: Move this some place else or remove
interface IOwnable {
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
}

// struct RoleConfiguration {
//     uint256 roleId;
//     address[] accounts;
// }

// struct AccessConfiguration {
//     uint256 permissionId;
//     address contractAddress;
//     uint256 roleId;
//     IRoleBasedAccessControl.Access access;
// }

// uint8 decimals; TODO ???

contract LensFactory {
    uint256 immutable ADMIN_ROLE_ID = uint256(keccak256("ADMIN"));
    AccountFactory internal immutable ACCOUNT_FACTORY;
    AppFactory internal immutable APP_FACTORY;
    GroupFactory internal immutable GROUP_FACTORY;
    FeedFactory internal immutable FEED_FACTORY;
    GraphFactory internal immutable GRAPH_FACTORY;
    UsernameFactory internal immutable USERNAME_FACTORY;
    IAccessControl internal immutable _factoryOwnedAccessControl;

    constructor(
        AccountFactory accountFactory,
        AppFactory appFactory,
        GroupFactory groupFactory,
        FeedFactory feedFactory,
        GraphFactory graphFactory,
        UsernameFactory usernameFactory
    ) {
        ACCOUNT_FACTORY = accountFactory;
        APP_FACTORY = appFactory;
        GROUP_FACTORY = groupFactory;
        FEED_FACTORY = feedFactory;
        GRAPH_FACTORY = graphFactory;
        USERNAME_FACTORY = usernameFactory;
        _factoryOwnedAccessControl = new RoleBasedAccessControl({owner: address(this)});
    }

    // TODO: This function belongs to an App probably.
    function createAccountWithUsernameFree(
        address metadataURISource,
        string calldata metadataURI,
        address owner,
        address[] calldata accountManagers,
        address usernamePrimitiveAddress,
        string calldata username,
        RuleExecutionData calldata createUsernameData,
        RuleExecutionData calldata assignUsernameData
    ) external returns (address) {
        address account = ACCOUNT_FACTORY.deployAccount(address(this), metadataURISource, metadataURI, accountManagers);
        IUsername usernamePrimitive = IUsername(usernamePrimitiveAddress);
        bytes memory txData = abi.encodeCall(usernamePrimitive.createUsername, (account, username, createUsernameData));
        IAccount(payable(account)).executeTransaction(usernamePrimitiveAddress, uint256(0), txData);
        txData = abi.encodeCall(usernamePrimitive.assignUsername, (account, username, assignUsernameData));
        IAccount(payable(account)).executeTransaction(usernamePrimitiveAddress, uint256(0), txData);
        IOwnable(account).transferOwnership(owner);
        return account;
    }

    function deployAccount(
        address metadataURISource,
        string memory metadataURI,
        address owner,
        address[] calldata accountManagers
    ) external returns (address) {
        return ACCOUNT_FACTORY.deployAccount(owner, metadataURISource, metadataURI, accountManagers);
    }

    function deployApp(
        address metadataURISource,
        string memory metadataURI,
        address owner,
        address[] calldata admins,
        AppInitialProperties calldata initialProperties,
        DataElement[] calldata extraData
    ) external returns (address) {
        return APP_FACTORY.deployApp(
            metadataURISource, metadataURI, _deployAccessControl(owner, admins), initialProperties, extraData
        );
    }

    function deployGroup(
        address metadataURISource,
        string memory metadataURI,
        address owner,
        address[] calldata admins,
        RuleConfiguration[] calldata rules,
        DataElement[] calldata extraData
    ) external returns (address) {
        return GROUP_FACTORY.deployGroup(
            metadataURISource, metadataURI, _deployAccessControl(owner, admins), rules, extraData
        );
    }

    function deployFeed(
        address metadataURISource,
        string memory metadataURI,
        address owner,
        address[] calldata admins,
        RuleConfiguration[] calldata rules,
        DataElement[] calldata extraData
    ) external returns (address) {
        return FEED_FACTORY.deployFeed(
            metadataURISource, metadataURI, _deployAccessControl(owner, admins), rules, extraData
        );
    }

    function deployGraph(
        address metadataURISource,
        string memory metadataURI,
        address owner,
        address[] calldata admins,
        RuleConfiguration[] calldata rules,
        DataElement[] calldata extraData
    ) external returns (address) {
        return GRAPH_FACTORY.deployGraph(
            metadataURISource, metadataURI, _deployAccessControl(owner, admins), rules, extraData
        );
    }

    function deployUsername(
        string memory namespace,
        address metadataURISource,
        string memory metadataURI,
        address owner,
        address[] calldata admins,
        RuleConfiguration[] calldata rules,
        DataElement[] calldata extraData,
        string memory nftName,
        string memory nftSymbol
    ) external returns (address) {
        ITokenURIProvider tokenURIProvider = new LensUsernameTokenURIProvider(); // TODO!
        return USERNAME_FACTORY.deployUsername(
            namespace,
            metadataURISource,
            metadataURI,
            _deployAccessControl(owner, admins),
            rules,
            extraData,
            nftName,
            nftSymbol,
            tokenURIProvider
        );
    }

    // function deployRoleBasedAccessControl(
    //     address owner,
    //     RoleConfiguration[] calldata roleConfigs,
    //     AccessConfiguration[] calldata accessConfigs
    // ) external returns (address) {
    //     RoleBasedAccessControl accessControl = new RoleBasedAccessControl({owner: address(this)});
    //     for (uint256 i = 0; i < roleConfigs.length; i++) {
    //         for (uint256 j = 0; j < roleConfigs[i].accounts.length; j++) {
    //             accessControl.grantRole(roleConfigs[i].accounts[j], roleConfigs[i].roleId);
    //         }
    //     }
    //     for (uint256 i = 0; i < accessConfigs.length; i++) {
    //         if (accessConfigs[i].contractAddress == address(0)) {
    //             accessControl.setGlobalAccess(
    //                 accessConfigs[i].roleId, accessConfigs[i].permissionId, accessConfigs[i].access, ""
    //             );
    //         } else {
    //             accessControl.setScopedAccess(
    //                 accessConfigs[i].roleId,
    //                 accessConfigs[i].contractAddress,
    //                 accessConfigs[i].permissionId,
    //                 accessConfigs[i].access,
    //                 ""
    //             );
    //         }
    //     }
    //     accessControl.transferOwnership(owner);
    //     return address(accessControl);
    // }

    function _deployAccessControl(address owner, address[] calldata admins)
        internal
        returns (IRoleBasedAccessControl)
    {
        RoleBasedAccessControl accessControl = new RoleBasedAccessControl({owner: address(this)});
        for (uint256 i = 0; i < admins.length; i++) {
            accessControl.grantRole(admins[i], ADMIN_ROLE_ID);
        }
        accessControl.transferOwnership(owner);
        return accessControl;
    }
}
