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

contract NamespaceTest is Test {
    IAccessControl accessControl;
    INamespace namespace;

    address account = makeAddr("ACCOUNT");

    function setUp() public {
        accessControl = new OwnerAdminOnlyAccessControl(address(this));
        namespace = new Namespace({
            namespace: "bitcoin",
            metadataURI: "satoshi://nakamoto",
            accessControl: accessControl,
            nftName: "Bitcoin",
            nftSymbol: "BTC",
            tokenURIProvider: new LensUsernameTokenURIProvider()
        });
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
