// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {INamespace} from "@core/interfaces/INamespace.sol";
import {Namespace} from "@core/primitives/namespace/Namespace.sol";
import "test/helpers/TypeHelpers.sol";
import {Errors} from "@core/types/Errors.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {WhitelistedSignersNamespaceRule} from "@rules/namespace/WhitelistedSignersNamespaceRule.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {RuleChange, RuleSelectorChange} from "@core/types/Types.sol";
import {INamespaceRule} from "@core/interfaces/INamespaceRule.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

/// @custom:keccak lens.param.accessControl
bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;
/// @custom:keccak lens.param.whitelistedSignersToAdd
bytes32 constant PARAM__WHITELISTED_SIGNERS_TO_ADD = 0x87a27ef0b9d4341d0c6acd2514645aeb8611ff1e356c98ff3af9f7f3abc3a1b2;
/// @custom:keccak lens.param.whitelistedSignersToRemove
bytes32 constant PARAM__WHITELISTED_SIGNERS_TO_REMOVE =
    0xcb9722f985c55a6e8242882fcb6beea2ee88b673b93cafecb87840c861aa3c46;

contract WhitelistedSignersNamespaceRuleTest is BaseDeployments {
    INamespace namespace;

    address namespaceOwner = makeAddr("NAMESPACE_OWNER");
    MockAccessControl accessControl;

    function setUp() public override {
        BaseDeployments.setUp();

        accessControl = new MockAccessControl();

        namespace = Namespace(
            lensFactory.deployNamespace({
                namespace: "bitcoin",
                metadataURI: "satoshi://nakamoto",
                owner: namespaceOwner,
                admins: new address[](0),
                rules: new RuleChange[](0),
                extraData: new KeyValue[](0),
                nftName: "Bitcoin",
                nftSymbol: "BTC"
            })
        );

        vm.label(address(namespace), "TEST_NAMESPACE");
        vm.label(namespaceOwner, "TEST_NAMESPACE_OWNER");

        KeyValue[] memory ruleParams = new KeyValue[](1);
        ruleParams[0] = KeyValue({key: PARAM__ACCESS_CONTROL, value: abi.encode(address(accessControl))});

        vm.prank(namespaceOwner);
        namespace.changeNamespaceRules(
            _toRuleChangeArray(
                whitelistedSignersNamespaceRule,
                0,
                ruleParams,
                RuleSelectorChange({
                    ruleSelector: INamespaceRule.processCreation.selector,
                    isRequired: true,
                    enabled: true
                })
            )
        );
    }

    function test_canAddWhitelistedSigner(address signerToAdd) public {
        vm.assume(signerToAdd != address(0));
        vm.assume(
            WhitelistedSignersNamespaceRule(whitelistedSignersNamespaceRule).isSignerWhitelisted(
                address(namespace), 0, signerToAdd
            ) == false
        );

        KeyValue[] memory ruleParams = new KeyValue[](1);
        ruleParams[0] =
            KeyValue({key: PARAM__WHITELISTED_SIGNERS_TO_ADD, value: abi.encode(_toAddressArray(signerToAdd))});

        vm.prank(namespaceOwner);
        namespace.changeNamespaceRules(_toRuleChangeArray(whitelistedSignersNamespaceRule, 3, ruleParams));

        assertEq(
            WhitelistedSignersNamespaceRule(whitelistedSignersNamespaceRule).isSignerWhitelisted(
                address(namespace), bytes32(uint256(3)), signerToAdd
            ),
            true
        );
    }

    function test_canRemoveWhitelistedSigner(address signerToRemove) public {
        vm.assume(signerToRemove != address(0));
        vm.assume(
            WhitelistedSignersNamespaceRule(whitelistedSignersNamespaceRule).isSignerWhitelisted(
                address(namespace), 0, signerToRemove
            ) == false
        );

        KeyValue[] memory ruleParamsAdd = new KeyValue[](2);
        ruleParamsAdd[0] =
            KeyValue({key: PARAM__WHITELISTED_SIGNERS_TO_ADD, value: abi.encode(_toAddressArray(signerToRemove))});

        vm.prank(namespaceOwner);
        namespace.changeNamespaceRules(_toRuleChangeArray(whitelistedSignersNamespaceRule, 3, ruleParamsAdd));

        assertEq(
            WhitelistedSignersNamespaceRule(whitelistedSignersNamespaceRule).isSignerWhitelisted(
                address(namespace), bytes32(uint256(3)), signerToRemove
            ),
            true
        );

        KeyValue[] memory ruleParamsRemove = new KeyValue[](2);
        ruleParamsRemove[0] =
            KeyValue({key: PARAM__WHITELISTED_SIGNERS_TO_REMOVE, value: abi.encode(_toAddressArray(signerToRemove))});

        vm.prank(namespaceOwner);
        namespace.changeNamespaceRules(_toRuleChangeArray(whitelistedSignersNamespaceRule, 3, ruleParamsRemove));

        assertEq(
            WhitelistedSignersNamespaceRule(whitelistedSignersNamespaceRule).isSignerWhitelisted(
                address(namespace), bytes32(uint256(3)), signerToRemove
            ),
            false
        );
    }

    function test_cannotCreateUsernameIfNotWhitelisted(address nonWhitelistedSigner) public {
        vm.assume(nonWhitelistedSigner != address(0));
        vm.assume(
            WhitelistedSignersNamespaceRule(whitelistedSignersNamespaceRule).isSignerWhitelisted(
                address(namespace), bytes32(uint256(3)), nonWhitelistedSigner
            ) == false
        );

        assumeNotForgeAddress(nonWhitelistedSigner);
        vm.assume(uint160(nonWhitelistedSigner) > type(uint16).max); // skip system contracts
        if (nonWhitelistedSigner.code.length != 0) {
            vm.assumeNoRevert();
            IERC721ReceiverUpgradeable(nonWhitelistedSigner).onERC721Received(address(namespace), address(0), 1, "");
        }

        vm.prank(nonWhitelistedSigner);
        vm.expectRevert(Errors.RequiredRuleReverted.selector);
        namespace.createUsername(
            nonWhitelistedSigner,
            "testusername12938",
            _emptyKeyValueArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyKeyValueArray()
        );
    }

    function test_canCreateUsernameIfWhitelisted(address whitelistedSigner) public {
        vm.assume(whitelistedSigner != address(0));
        vm.assume(
            WhitelistedSignersNamespaceRule(whitelistedSignersNamespaceRule).isSignerWhitelisted(
                address(namespace), bytes32(uint256(3)), whitelistedSigner
            ) == false
        );

        assumeNotForgeAddress(whitelistedSigner);
        vm.assume(uint160(whitelistedSigner) > type(uint16).max); // skip system contracts
        if (whitelistedSigner.code.length != 0) {
            vm.assumeNoRevert();
            IERC721ReceiverUpgradeable(whitelistedSigner).onERC721Received(address(namespace), address(0), 1, "");
        }

        KeyValue[] memory ruleParams = new KeyValue[](1);
        ruleParams[0] =
            KeyValue({key: PARAM__WHITELISTED_SIGNERS_TO_ADD, value: abi.encode(_toAddressArray(whitelistedSigner))});

        vm.prank(namespaceOwner);
        namespace.changeNamespaceRules(_toRuleChangeArray(whitelistedSignersNamespaceRule, 3, ruleParams));

        assertEq(
            WhitelistedSignersNamespaceRule(whitelistedSignersNamespaceRule).isSignerWhitelisted(
                address(namespace), bytes32(uint256(3)), whitelistedSigner
            ),
            true
        );

        vm.prank(whitelistedSigner);
        namespace.createUsername(
            whitelistedSigner,
            "testusername12938",
            _emptyKeyValueArray(),
            _emptyRuleProcessingParamsArray(),
            _emptyKeyValueArray()
        );

        assertEq(namespace.exists("testusername12938"), true);
        assertEq(namespace.ownerOf("testusername12938"), whitelistedSigner);
    }
}
