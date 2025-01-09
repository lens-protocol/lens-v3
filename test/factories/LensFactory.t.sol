// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {LensFactory} from "@extensions/factories/LensFactory.sol";
import {AccountFactory} from "@extensions/factories/AccountFactory.sol";
import {AppFactory} from "@extensions/factories/AppFactory.sol";
import {GroupFactory} from "@extensions/factories/GroupFactory.sol";
import {FeedFactory} from "@extensions/factories/FeedFactory.sol";
import {GraphFactory} from "@extensions/factories/GraphFactory.sol";
import {NamespaceFactory} from "@extensions/factories/NamespaceFactory.sol";
import {Namespace} from "@core/primitives/namespace/Namespace.sol";
import {RuleChange, KeyValue} from "@core/types/Types.sol";
import {AccountManagerPermissions} from "@extensions/account/Account.sol";
import {AccessControlFactory} from "@extensions/factories/AccessControlFactory.sol";
import {AccountBlockingRule} from "contracts/rules/base/AccountBlockingRule.sol";
import {IGraph} from "@core/interfaces/IGraph.sol";
import {GroupGatedFeedRule} from "contracts/rules/feed/GroupGatedFeedRule.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";

contract LensFactoryTest is Test, BaseDeployments {
    Namespace namespace;

    function setUp() public override {
        super.setUp();
        namespace = Namespace(
            lensFactory.deployNamespace({
                namespace: "bitcoin",
                metadataURI: "satoshi://nakamoto",
                owner: address(this),
                admins: new address[](0),
                rules: new RuleChange[](0),
                extraData: new KeyValue[](0),
                nftName: "Bitcoin",
                nftSymbol: "BTC"
            })
        );
    }

    function testCanDeployFeed() public {
        lensFactory.deployFeed({
            metadataURI: "uri://any",
            owner: address(this),
            admins: _emptyAddressArray(),
            rules: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function testCreateAccountWithUsernameFree() public {
        lensFactory.createAccountWithUsernameFree({
            metadataURI: "someMetadataURI",
            owner: address(this),
            accountManagers: _emptyAddressArray(),
            accountManagersPermissions: new AccountManagerPermissions[](0),
            namespacePrimitiveAddress: address(namespace),
            username: "myTestUsername",
            accountCreationSourceStamp: _emptySourceStamp(),
            createUsernameCustomParams: _emptyKeyValueArray(),
            createUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignUsernameCustomParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            accountExtraData: _emptyKeyValueArray(),
            usernameExtraData: _emptyKeyValueArray()
        });
    }

    function testGraphFollowWithFactorySetup() public {
        IGraph graph = IGraph(
            lensFactory.deployGraph({
                metadataURI: "uri://any",
                owner: address(this),
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );
        graph.follow({
            followerAccount: address(this),
            targetAccount: address(0xc0ffee),
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }
}
