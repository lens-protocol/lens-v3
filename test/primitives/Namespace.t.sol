// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "@dashboard/access/OwnerAdminOnlyAccessControl.sol";
import {INamespace} from "@core/interfaces/INamespace.sol";
import {Namespace} from "@core/primitives/namespace/Namespace.sol";
import {LensUsernameTokenURIProvider} from "@core/primitives/namespace/LensUsernameTokenURIProvider.sol";
import "../helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";

contract NamespaceTest is Test, BaseDeployments {
    INamespace namespace;

    address account = makeAddr("ACCOUNT");
    address namespaceOwner = makeAddr("NAMESPACE_OWNER");

    function setUp() public override {
        super.setUp();

        namespace = INamespace(
            lensFactory.deployNamespace({
                namespace: "bitcoin",
                metadataURI: "satoshi://nakamoto",
                owner: namespaceOwner,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray(),
                nftName: "Bitcoin",
                nftSymbol: "BTC"
            })
        );
    }

    function testCreateAssignUnassignDelete() public {
        string memory localName = "satoshi";

        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        vm.prank(account);
        namespace.assignUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        vm.prank(account);
        namespace.unassignUsername({
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        vm.prank(account);
        namespace.removeUsername({
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassigningRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            removalRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }
}
