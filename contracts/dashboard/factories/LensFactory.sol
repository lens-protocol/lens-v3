// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IRoleBasedAccessControl} from "./../../core/interfaces/IRoleBasedAccessControl.sol";
import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {Group} from "./../../core/primitives/group/Group.sol";
import {RoleBasedAccessControl} from "./../../core/access/RoleBasedAccessControl.sol";
import {
    RuleConfigurationChange,
    RuleSelectorChange,
    RuleProcessingParams,
    KeyValue,
    SourceStamp
} from "./../../core/types/Types.sol";
import {GroupFactory} from "./GroupFactory.sol";
import {FeedFactory} from "./FeedFactory.sol";
import {GraphFactory} from "./GraphFactory.sol";
import {UsernameFactory} from "./UsernameFactory.sol";
import {AppFactory, AppInitialProperties} from "./AppFactory.sol";
import {AccessControlFactory} from "./AccessControlFactory.sol";
import {AccountFactory} from "./AccountFactory.sol";
import {IAccount, AccountManagerPermissions} from "./../account/IAccount.sol";
import {IUsername} from "./../../core/interfaces/IUsername.sol";
import {ITokenURIProvider} from "./../../core/interfaces/ITokenURIProvider.sol";
import {LensUsernameTokenURIProvider} from "./../../core/primitives/username/LensUsernameTokenURIProvider.sol";
import {IFeedRule} from "./../../core/interfaces/IFeedRule.sol";
import {IGraphRule} from "./../../core/interfaces/IGraphRule.sol";

// TODO: Move this some place else or remove
interface IOwnable {
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
}

// struct AccessConfiguration {
//     uint256 permissionId;
//     address contractAddress;
//     uint256 roleId;
//     IRoleBasedAccessControl.Access access;
// }

// uint8 decimals; TODO ???

contract LensFactory {
    AccessControlFactory internal immutable ACCESS_CONTROL_FACTORY;
    AccountFactory internal immutable ACCOUNT_FACTORY;
    AppFactory internal immutable APP_FACTORY;
    GroupFactory internal immutable GROUP_FACTORY;
    FeedFactory internal immutable FEED_FACTORY;
    GraphFactory internal immutable GRAPH_FACTORY;
    UsernameFactory internal immutable USERNAME_FACTORY;
    IAccessControl internal immutable _factoryOwnedAccessControl;
    address internal immutable _userBlockingRule;

    constructor(
        AccessControlFactory accessControlFactory,
        AccountFactory accountFactory,
        AppFactory appFactory,
        GroupFactory groupFactory,
        FeedFactory feedFactory,
        GraphFactory graphFactory,
        UsernameFactory usernameFactory,
        address userBlockingRule
    ) {
        ACCESS_CONTROL_FACTORY = accessControlFactory;
        ACCOUNT_FACTORY = accountFactory;
        APP_FACTORY = appFactory;
        GROUP_FACTORY = groupFactory;
        FEED_FACTORY = feedFactory;
        GRAPH_FACTORY = graphFactory;
        USERNAME_FACTORY = usernameFactory;
        _factoryOwnedAccessControl = new RoleBasedAccessControl({owner: address(this)});
        _userBlockingRule = userBlockingRule;
    }

    // TODO: This function belongs to an App probably.
    function createAccountWithUsernameFree(
        string calldata metadataURI,
        address owner,
        address[] calldata accountManagers,
        AccountManagerPermissions[] calldata accountManagersPermissions,
        address usernamePrimitiveAddress,
        string calldata username,
        SourceStamp calldata accountCreationSourceStamp,
        KeyValue[] calldata createUsernameCustomParams,
        RuleProcessingParams[] calldata createUsernameRuleProcessingParams,
        KeyValue[] calldata assignUsernameCustomParams,
        RuleProcessingParams[] calldata unassignAccountRuleProcessingParams,
        RuleProcessingParams[] calldata assignRuleProcessingParams
    ) external returns (address) {
        address account = ACCOUNT_FACTORY.deployAccount(
            address(this), metadataURI, accountManagers, accountManagersPermissions, accountCreationSourceStamp
        );
        IUsername usernamePrimitive = IUsername(usernamePrimitiveAddress);
        bytes memory txData = abi.encodeCall(
            usernamePrimitive.createUsername,
            (account, username, createUsernameCustomParams, createUsernameRuleProcessingParams)
        );
        IAccount(payable(account)).executeTransaction(usernamePrimitiveAddress, uint256(0), txData);
        txData = abi.encodeCall(
            usernamePrimitive.assignUsername,
            (
                account,
                username,
                assignUsernameCustomParams,
                unassignAccountRuleProcessingParams,
                new RuleProcessingParams[](0),
                assignRuleProcessingParams
            )
        );
        IAccount(payable(account)).executeTransaction(usernamePrimitiveAddress, uint256(0), txData);
        IOwnable(account).transferOwnership(owner);
        return account;
    }

    function deployAccount(
        string calldata metadataURI,
        address owner,
        address[] calldata accountManagers,
        AccountManagerPermissions[] calldata accountManagersPermissions,
        SourceStamp calldata sourceStamp
    ) external returns (address) {
        return
            ACCOUNT_FACTORY.deployAccount(owner, metadataURI, accountManagers, accountManagersPermissions, sourceStamp);
    }

    function deployApp(
        string calldata metadataURI,
        bool sourceStampVerificationEnabled,
        address owner,
        address[] calldata admins,
        AppInitialProperties calldata initialProperties,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return APP_FACTORY.deployApp(
            metadataURI,
            sourceStampVerificationEnabled,
            _deployAccessControl(owner, admins),
            initialProperties,
            extraData
        );
    }

    function deployGroup(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return GROUP_FACTORY.deployGroup(
            metadataURI, _deployAccessControl(owner, admins), configChanges, selectorChanges, extraData
        );
    }

    function deployFeed(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        bytes4[] memory ruleSelectors = new bytes4[](1);
        ruleSelectors[0] = IFeedRule.processCreatePost.selector;

        (RuleConfigurationChange[] memory modifiedConfigChanges, RuleSelectorChange[] memory modifiedSelectorChanges) =
            _prependUserBlocking(configChanges, selectorChanges, ruleSelectors);

        return FEED_FACTORY.deployFeed(
            metadataURI, _deployAccessControl(owner, admins), modifiedConfigChanges, modifiedSelectorChanges, extraData
        );
    }

    function _prependUserBlocking(
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        bytes4[] memory ruleSelectors
    ) internal view returns (RuleConfigurationChange[] memory, RuleSelectorChange[] memory) {
        RuleConfigurationChange[] memory modifiedConfigChanges = new RuleConfigurationChange[](configChanges.length + 1);
        RuleSelectorChange[] memory modifiedSelectorChanges = new RuleSelectorChange[](selectorChanges.length + 1);

        modifiedConfigChanges[0] = RuleConfigurationChange({
            ruleAddress: _userBlockingRule,
            configSalt: bytes32(uint256(1)),
            ruleParams: new KeyValue[](0)
        });
        for (uint256 i = 0; i < configChanges.length; i++) {
            modifiedConfigChanges[i + 1] = modifiedConfigChanges[i];
        }

        modifiedSelectorChanges[0] = RuleSelectorChange({
            ruleAddress: _userBlockingRule,
            configSalt: bytes32(uint256(1)),
            isRequired: true,
            ruleSelectors: ruleSelectors,
            enabled: true
        });
        for (uint256 i = 0; i < selectorChanges.length; i++) {
            modifiedSelectorChanges[i + 1] = modifiedSelectorChanges[i];
        }

        return (modifiedConfigChanges, modifiedSelectorChanges);
    }

    function deployGraph(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        bytes4[] memory ruleSelectors = new bytes4[](1);
        ruleSelectors[0] = IGraphRule.processFollow.selector;

        (RuleConfigurationChange[] memory modifiedConfigChanges, RuleSelectorChange[] memory modifiedSelectorChanges) =
            _prependUserBlocking(configChanges, selectorChanges, ruleSelectors);

        return GRAPH_FACTORY.deployGraph(
            metadataURI, _deployAccessControl(owner, admins), modifiedConfigChanges, modifiedSelectorChanges, extraData
        );
    }

    function deployUsername(
        string calldata namespace,
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        KeyValue[] calldata extraData,
        string calldata nftName,
        string calldata nftSymbol
    ) external returns (address) {
        ITokenURIProvider tokenURIProvider = new LensUsernameTokenURIProvider(); // TODO!
        return USERNAME_FACTORY.deployUsername(
            namespace,
            metadataURI,
            _deployAccessControl(owner, admins),
            configChanges,
            selectorChanges,
            extraData,
            nftName,
            nftSymbol,
            tokenURIProvider
        );
    }

    function _deployAccessControl(address owner, address[] calldata admins) internal returns (IRoleBasedAccessControl) {
        return ACCESS_CONTROL_FACTORY.deployOwnerAdminOnlyAccessControl(owner, admins);
    }
}