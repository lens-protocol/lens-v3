// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {
    LensFactory,
    CreateAccountParams,
    CreateUsernameParams,
    AccountManagerPermissions
} from "contracts/extensions/factories/LensFactory.sol";
import {IRoleBasedAccessControl} from "contracts/core/interfaces/IRoleBasedAccessControl.sol";
import {RuleChange, SourceStamp, KeyValue, RuleProcessingParams} from "contracts/core/types/Types.sol";
import {PermissionlessAccessControl} from "contracts/extensions/access/PermissionlessAccessControl.sol";
import {AccessControlFactory} from "contracts/extensions/factories/AccessControlFactory.sol";
import {AccountFactory} from "contracts/extensions/factories/AccountFactory.sol";
import {AppFactory} from "contracts/extensions/factories/AppFactory.sol";
import {GroupFactory} from "contracts/extensions/factories/GroupFactory.sol";
import {FeedFactory} from "contracts/extensions/factories/FeedFactory.sol";
import {GraphFactory} from "contracts/extensions/factories/GraphFactory.sol";
import {NamespaceFactory} from "contracts/extensions/factories/NamespaceFactory.sol";
import {WHITELISTED_MULTICALL_ADDRESS} from "contracts/migration/WhitelistedMulticall.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Namespace} from "contracts/core/primitives/namespace/Namespace.sol";
import {IOwnable} from "contracts/core/interfaces/IOwnable.sol";
import {IAccount} from "contracts/extensions/account/IAccount.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";

contract MigrationLensFactory is LensFactory {
    constructor(
        AccessControlFactory accessControlFactory,
        AccountFactory accountFactory,
        AppFactory appFactory,
        GroupFactory groupFactory,
        FeedFactory feedFactory,
        GraphFactory graphFactory,
        NamespaceFactory namespaceFactory,
        address accountBlockingRule,
        address groupGatedFeedRule,
        address usernameSimpleCharsetRule
    )
        LensFactory(
            accessControlFactory,
            accountFactory,
            appFactory,
            groupFactory,
            feedFactory,
            graphFactory,
            namespaceFactory,
            accountBlockingRule,
            groupGatedFeedRule,
            usernameSimpleCharsetRule
        )
    {}

    modifier onlyWhitelistedMulticall() {
        require(msg.sender == WHITELISTED_MULTICALL_ADDRESS, Errors.InvalidMsgSender());
        _;
    }

    function createAccountWithUsernameFree(
        address namespacePrimitiveAddress,
        CreateAccountParams calldata accountParams,
        CreateUsernameParams calldata usernameParams
    ) external override onlyWhitelistedMulticall returns (address) {
        address account = ACCOUNT_FACTORY.deployAccount(
            accountParams.owner,
            accountParams.metadataURI,
            accountParams.accountManagers,
            accountParams.accountManagersPermissions,
            accountParams.accountCreationSourceStamp,
            accountParams.accountExtraData
        );
        Namespace(namespacePrimitiveAddress).createAndAssignUsername({
            account: account,
            username: usernameParams.username,
            customParams: usernameParams.createUsernameCustomParams,
            unassigningProcessingParams: new RuleProcessingParams[](0),
            creationProcessingParams: usernameParams.createUsernameRuleProcessingParams,
            assigningProcessingParams: usernameParams.assignRuleProcessingParams,
            extraData: usernameParams.usernameExtraData
        });
        return account;
    }

    function deployAccount(
        string calldata metadataURI,
        address owner,
        address[] calldata accountManagers,
        AccountManagerPermissions[] calldata accountManagersPermissions,
        SourceStamp calldata sourceStamp,
        KeyValue[] calldata extraData
    ) external override onlyWhitelistedMulticall returns (address) {
        return ACCOUNT_FACTORY.deployAccount(
            owner, metadataURI, accountManagers, accountManagersPermissions, sourceStamp, extraData
        );
    }

    function _deployAccessControl(address, /* owner */ address[] memory /* admins */ )
        internal
        override
        returns (IRoleBasedAccessControl)
    {
        PermissionlessAccessControl accessControl = new PermissionlessAccessControl();
        return IRoleBasedAccessControl(address(accessControl));
    }

    function _injectRuleAccessControl(RuleChange memory rule, address /* accessControl */ )
        internal
        pure
        override
        returns (RuleChange memory)
    {
        return rule;
    }

    function _injectRuleAccessControl(RuleChange[] memory rules, address /* accessControl */ )
        internal
        pure
        override
        returns (RuleChange[] memory)
    {
        return rules;
    }

    function _prepareRules(RuleChange[] memory rules, bytes4, /* ruleSelector */ address /* accessControl */ )
        internal
        pure
        override
        returns (RuleChange[] memory)
    {
        return rules;
    }

    function _injectRulesForFeedAndGroup(
        RuleChange[] memory feedRules,
        IRoleBasedAccessControl, /* feedAccessControl */
        address /* group */
    ) internal pure override returns (RuleChange[] memory) {
        return feedRules;
    }

    function _injectRulesForNamespace(RuleChange[] memory rules, address /* accessControl */ )
        internal
        pure
        override
        returns (RuleChange[] memory)
    {
        return rules;
    }
}
