// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IRoleBasedAccessControl} from "./../../core/interfaces/IRoleBasedAccessControl.sol";
import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {Group} from "./../../core/primitives/group/Group.sol";
import {RoleBasedAccessControl} from "./../../core/access/RoleBasedAccessControl.sol";
import {
    RuleChange,
    RuleProcessingParams,
    RuleSelectorChange,
    RuleConfigurationChange,
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
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return GROUP_FACTORY.deployGroup(metadataURI, _deployAccessControl(owner, admins), ruleChanges, extraData);
    }

    function deployFeed(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return FEED_FACTORY.deployFeed(
            metadataURI,
            _deployAccessControl(owner, admins),
            _prependUserBlocking(ruleChanges, IFeedRule.processCreatePost.selector),
            extraData
        );
    }

    function _prependUserBlocking(
        RuleChange[] calldata ruleChanges,
        bytes4 ruleSelector
    ) internal view returns (RuleChange[] memory) {
        RuleChange[] memory modifiedRuleChanges = new RuleChange[](ruleChanges.length + 1);

        RuleSelectorChange[] memory selectorChanges = new RuleSelectorChange[](1);
        selectorChanges[0] = RuleSelectorChange({ruleSelector: ruleSelector, isRequired: true, enabled: true});

        modifiedRuleChanges[0] = RuleChange({
            ruleAddress: _userBlockingRule,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: selectorChanges
        });
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            modifiedRuleChanges[i + 1] = modifiedRuleChanges[i];
        }

        return modifiedRuleChanges;
    }

    function deployGraph(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return GRAPH_FACTORY.deployGraph(
            metadataURI,
            _deployAccessControl(owner, admins),
            _prependUserBlocking(ruleChanges, IGraphRule.processFollow.selector),
            extraData
        );
    }

    function deployUsername(
        string calldata namespace,
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData,
        string calldata nftName,
        string calldata nftSymbol
    ) external returns (address) {
        ITokenURIProvider tokenURIProvider = new LensUsernameTokenURIProvider(); // TODO!
        return USERNAME_FACTORY.deployUsername(
            namespace,
            metadataURI,
            _deployAccessControl(owner, admins),
            ruleChanges,
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
