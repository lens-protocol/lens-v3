// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IRoleBasedAccessControl} from "contracts/core/interfaces/IRoleBasedAccessControl.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Group} from "contracts/core/primitives/group/Group.sol";
import {PermissionlessAccessControl} from "contracts/extensions/access/PermissionlessAccessControl.sol";
import {
    RuleChange,
    RuleProcessingParams,
    RuleSelectorChange,
    RuleConfigurationChange,
    KeyValue,
    SourceStamp
} from "contracts/core/types/Types.sol";
import {GroupFactory} from "contracts/extensions/factories/GroupFactory.sol";
import {FeedFactory} from "contracts/extensions/factories/FeedFactory.sol";
import {GraphFactory} from "contracts/extensions/factories/GraphFactory.sol";
import {NamespaceFactory} from "contracts/extensions/factories/NamespaceFactory.sol";
import {AppFactory} from "contracts/extensions/factories/AppFactory.sol";
import {AppInitialProperties} from "contracts/extensions/primitives/app/App.sol";
import {AccessControlFactory} from "contracts/extensions/factories/AccessControlFactory.sol";
import {AccountFactory} from "contracts/extensions/factories/AccountFactory.sol";
import {IAccount, AccountManagerPermissions} from "contracts/extensions/account/IAccount.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";
import {ITokenURIProvider} from "contracts/core/interfaces/ITokenURIProvider.sol";
import {LensUsernameTokenURIProvider} from "contracts/core/primitives/namespace/LensUsernameTokenURIProvider.sol";
import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";
import {IGraphRule} from "contracts/core/interfaces/IGraphRule.sol";
import {PARAM__GROUP} from "contracts/rules/feed/GroupGatedFeedRule.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {IGroup} from "contracts/core/interfaces/IGroup.sol";

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

/// @custom:keccak lens.data.groupFeed
bytes32 constant DATA__GROUP_LINKED_FEED = 0xfec1c12508813d27a0104e0d1f0ad007b92d4ee5701c6d20b721221326b94ae1;

contract LensFactory {
    AccessControlFactory internal immutable ACCESS_CONTROL_FACTORY;
    AccountFactory internal immutable ACCOUNT_FACTORY;
    AppFactory internal immutable APP_FACTORY;
    GroupFactory internal immutable GROUP_FACTORY;
    FeedFactory internal immutable FEED_FACTORY;
    GraphFactory internal immutable GRAPH_FACTORY;
    NamespaceFactory internal immutable NAMESPACE_FACTORY;
    IAccessControl internal immutable _temporaryAccessControl;
    address internal immutable _accountBlockingRule;
    address internal immutable _groupGatedFeedRule;

    constructor(
        AccessControlFactory accessControlFactory,
        AccountFactory accountFactory,
        AppFactory appFactory,
        GroupFactory groupFactory,
        FeedFactory feedFactory,
        GraphFactory graphFactory,
        NamespaceFactory namespaceFactory,
        address accountBlockingRule,
        address groupGatedFeedRule
    ) {
        ACCESS_CONTROL_FACTORY = accessControlFactory;
        ACCOUNT_FACTORY = accountFactory;
        APP_FACTORY = appFactory;
        GROUP_FACTORY = groupFactory;
        FEED_FACTORY = feedFactory;
        GRAPH_FACTORY = graphFactory;
        NAMESPACE_FACTORY = namespaceFactory;
        _temporaryAccessControl = new PermissionlessAccessControl();
        _accountBlockingRule = accountBlockingRule;
        _groupGatedFeedRule = groupGatedFeedRule;
    }

    // TODO: This function belongs to an App probably.
    function createAccountWithUsernameFree(
        string calldata metadataURI,
        address owner,
        address[] calldata accountManagers,
        AccountManagerPermissions[] calldata accountManagersPermissions,
        address namespacePrimitiveAddress,
        string calldata username,
        SourceStamp calldata accountCreationSourceStamp,
        KeyValue[] calldata createUsernameCustomParams,
        RuleProcessingParams[] calldata createUsernameRuleProcessingParams,
        KeyValue[] calldata assignUsernameCustomParams,
        RuleProcessingParams[] calldata unassignAccountRuleProcessingParams,
        RuleProcessingParams[] calldata assignRuleProcessingParams,
        KeyValue[] calldata accountExtraData,
        KeyValue[] calldata usernameExtraData
    ) external returns (address) {
        address account = ACCOUNT_FACTORY.deployAccount(
            address(this),
            metadataURI,
            accountManagers,
            accountManagersPermissions,
            accountCreationSourceStamp,
            accountExtraData
        );
        INamespace namespacePrimitive = INamespace(namespacePrimitiveAddress);
        bytes memory txData = abi.encodeCall(
            namespacePrimitive.createUsername,
            (account, username, createUsernameCustomParams, createUsernameRuleProcessingParams, usernameExtraData)
        );
        IAccount(payable(account)).executeTransaction(namespacePrimitiveAddress, uint256(0), txData);
        txData = abi.encodeCall(
            namespacePrimitive.assignUsername,
            (
                account,
                username,
                assignUsernameCustomParams,
                unassignAccountRuleProcessingParams,
                new RuleProcessingParams[](0),
                assignRuleProcessingParams
            )
        );
        IAccount(payable(account)).executeTransaction(namespacePrimitiveAddress, uint256(0), txData);
        IOwnable(account).transferOwnership(owner);
        return account;
    }

    function createGroupWithFeed(
        address owner,
        address[] calldata admins,
        string calldata groupMetadataURI,
        RuleChange[] calldata groupRules,
        KeyValue[] calldata groupExtraData,
        string calldata feedMetadataURI,
        RuleChange[] calldata feedRules,
        KeyValue[] calldata feedExtraData
    ) external returns (address, address) {
        address group =
            GROUP_FACTORY.deployGroup(groupMetadataURI, _temporaryAccessControl, owner, groupRules, groupExtraData);

        RuleChange[] memory modifiedFeedRules = new RuleChange[](feedRules.length + 2);

        RuleSelectorChange[] memory selectorChanges = new RuleSelectorChange[](1);
        // Both rules only operate on IFeedRule.processCreatePost.selector (at least at the moment of writing this)
        selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IFeedRule.processCreatePost.selector, isRequired: true, enabled: true});

        modifiedFeedRules[0] = RuleChange({
            ruleAddress: _accountBlockingRule,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: selectorChanges
        });

        KeyValue[] memory groupGatedRuleParams = new KeyValue[](1);
        groupGatedRuleParams[0] = KeyValue({key: PARAM__GROUP, value: abi.encode(group)});

        modifiedFeedRules[1] = RuleChange({
            ruleAddress: _groupGatedFeedRule,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: groupGatedRuleParams}),
            selectorChanges: selectorChanges
        });

        for (uint256 i = 0; i < feedRules.length; i++) {
            require(feedRules[i].ruleAddress != _accountBlockingRule, "AccountBlockingRule was already prepended");
            require(feedRules[i].ruleAddress != _groupGatedFeedRule, "GroupGatedRule was already prepended");
            modifiedFeedRules[i + 2] = feedRules[i];
        }

        address feed = FEED_FACTORY.deployFeed(
            feedMetadataURI, _deployAccessControl(owner, admins), owner, modifiedFeedRules, feedExtraData
        );

        IRoleBasedAccessControl groupAccessControl = _deployAccessControl(owner, admins);
        KeyValue[] memory groupExtraDataWithFeed = new KeyValue[](1);
        groupExtraDataWithFeed[0] = KeyValue({key: DATA__GROUP_LINKED_FEED, value: abi.encode(feed)});
        IGroup(group).setExtraData(groupExtraDataWithFeed);
        AccessControlled(group).setAccessControl(groupAccessControl);
        return (group, feed);
    }

    function deployAccount(
        string calldata metadataURI,
        address owner,
        address[] calldata accountManagers,
        AccountManagerPermissions[] calldata accountManagersPermissions,
        SourceStamp calldata sourceStamp,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return ACCOUNT_FACTORY.deployAccount(
            owner, metadataURI, accountManagers, accountManagersPermissions, sourceStamp, extraData
        );
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
            owner,
            initialProperties,
            extraData
        );
    }

    function deployGroup(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleChange[] calldata rules,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return GROUP_FACTORY.deployGroup(metadataURI, _deployAccessControl(owner, admins), owner, rules, extraData);
    }

    function deployFeed(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleChange[] calldata rules,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return FEED_FACTORY.deployFeed(
            metadataURI,
            _deployAccessControl(owner, admins),
            owner,
            _prependAccountBlocking(rules, IFeedRule.processCreatePost.selector),
            extraData
        );
    }

    function _prependAccountBlocking(RuleChange[] calldata rules, bytes4 ruleSelector)
        internal
        view
        returns (RuleChange[] memory)
    {
        RuleChange[] memory modifiedRules = new RuleChange[](rules.length + 1);

        RuleSelectorChange[] memory selectorChanges = new RuleSelectorChange[](1);
        selectorChanges[0] = RuleSelectorChange({ruleSelector: ruleSelector, isRequired: true, enabled: true});

        modifiedRules[0] = RuleChange({
            ruleAddress: _accountBlockingRule,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: selectorChanges
        });
        for (uint256 i = 0; i < rules.length; i++) {
            require(rules[i].ruleAddress != _accountBlockingRule, "AccountBlockingRule was already prepended");
            modifiedRules[i + 1] = rules[i];
        }

        return modifiedRules;
    }

    function deployGraph(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleChange[] calldata rules,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return GRAPH_FACTORY.deployGraph(
            metadataURI,
            _deployAccessControl(owner, admins),
            owner,
            _prependAccountBlocking(rules, IGraphRule.processFollow.selector),
            extraData
        );
    }

    function deployNamespace(
        string calldata namespace,
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleChange[] calldata rules,
        KeyValue[] calldata extraData,
        string calldata nftName,
        string calldata nftSymbol
    ) external returns (address) {
        ITokenURIProvider tokenURIProvider = new LensUsernameTokenURIProvider();
        return NAMESPACE_FACTORY.deployNamespace(
            namespace,
            metadataURI,
            _deployAccessControl(owner, admins),
            owner,
            rules,
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
