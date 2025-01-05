// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {LensFactory} from "@dashboard/factories/LensFactory.sol";
import {AccountFactory} from "@dashboard/factories/AccountFactory.sol";
import {AppFactory} from "@dashboard/factories/AppFactory.sol";
import {GroupFactory} from "@dashboard/factories/GroupFactory.sol";
import {FeedFactory} from "@dashboard/factories/FeedFactory.sol";
import {GraphFactory} from "@dashboard/factories/GraphFactory.sol";
import {NamespaceFactory} from "@dashboard/factories/NamespaceFactory.sol";
import {Namespace} from "@core/primitives/namespace/Namespace.sol";
import {RuleChange, KeyValue} from "@core/types/Types.sol";
import {AccountManagerPermissions} from "@dashboard/account/Account.sol";
import {AccessControlFactory} from "@dashboard/factories/AccessControlFactory.sol";
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
