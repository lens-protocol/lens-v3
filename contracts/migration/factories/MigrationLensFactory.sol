// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {LensFactory} from "contracts/extensions/factories/LensFactory.sol";
import {IRoleBasedAccessControl} from "contracts/core/interfaces/IRoleBasedAccessControl.sol";
import {RuleChange} from "contracts/core/types/Types.sol";
import {PermissionlessAccessControl} from "contracts/extensions/access/PermissionlessAccessControl.sol";
import {AccessControlFactory} from "contracts/extensions/factories/AccessControlFactory.sol";
import {AccountFactory} from "contracts/extensions/factories/AccountFactory.sol";
import {AppFactory} from "contracts/extensions/factories/AppFactory.sol";
import {GroupFactory} from "contracts/extensions/factories/GroupFactory.sol";
import {FeedFactory} from "contracts/extensions/factories/FeedFactory.sol";
import {GraphFactory} from "contracts/extensions/factories/GraphFactory.sol";
import {NamespaceFactory} from "contracts/extensions/factories/NamespaceFactory.sol";

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
        address usernameSimpleCharsetRule,
        address banMemberGroupRule
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
            usernameSimpleCharsetRule,
            banMemberGroupRule
        )
    {}

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
