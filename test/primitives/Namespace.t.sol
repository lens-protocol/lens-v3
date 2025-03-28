// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {Errors} from "@core/types/Errors.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {IAccessControlled} from "@core/interfaces/IAccessControlled.sol";
import {IERC721Namespace} from "@core/interfaces/IERC721Namespace.sol";
import {IMetadataBased} from "@core/interfaces/IMetadataBased.sol";
import {INamespace} from "@core/interfaces/INamespace.sol";
import {INamespaceRule} from "@core/interfaces/INamespaceRule.sol";
import {IOwnable} from "@core/interfaces/IOwnable.sol";
import {LensERC721} from "@core/base/LensERC721.sol";
import {LensUsernameTokenURIProvider} from "@core/primitives/namespace/LensUsernameTokenURIProvider.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {Namespace} from "@core/primitives/namespace/Namespace.sol";
import {Rule} from "@core/types/Types.sol";
import {RuleExecutionTest} from "test/primitives/rules/RuleExecution.t.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";

contract NamespaceTest is RulesTest, BaseDeployments, RuleExecutionTest {
    /// @custom:keccak lens.permission.AssignUsername
    uint256 constant PID__ASSIGN_USERNAME = uint256(0x6ed127ecda9c702e81990b9c822ee95d9238c4141f2d4fbaa05c6ba3df0ec6ce);

    INamespace namespace;

    address account = makeAddr("ACCOUNT");
    address namespaceOwner = makeAddr("NAMESPACE_OWNER");

    MockAccessControl mockAccessControl;
    address namespaceForRules;

    function setUp() public override(RulesTest, BaseDeployments, RuleExecutionTest) {
        BaseDeployments.setUp();

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

        mockAccessControl = new MockAccessControl();

        LensUsernameTokenURIProvider tokenURIProvider = new LensUsernameTokenURIProvider();

        vm.prank(address(lensFactory));
        namespaceForRules = namespaceFactory.deployNamespace({
            namespace: "ethereum",
            metadataURI: "vitalik://buterin",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray(),
            nftName: "Ethereum",
            nftSymbol: "ETH",
            tokenURIProvider: tokenURIProvider
        });

        RulesTest.setUp();

        RuleExecutionTest.setUp();
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

        assertEq(namespace.ownerOf(localName), account, "Owner of the username should be the account");

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

    function test_CannotCreateEmptyUsername() public {
        vm.prank(account);
        vm.expectRevert(Errors.InvalidParameter.selector);
        namespace.createUsername({
            account: account,
            username: "",
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function test_CannotCreateDuplicateUsername() public {
        string memory localName = "satoshi";

        // First creation should succeed
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Second creation should fail
        vm.prank(account);
        vm.expectRevert(Errors.AlreadyExists.selector);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function test_CreateUsername() public {
        string memory localName = "satoshi";

        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify username exists
        assertTrue(namespace.exists(localName), "Username should exist");

        // Verify owner of the username
        assertEq(namespace.ownerOf(localName), account, "Owner of the username should be the account");

        // Verify username is not assigned
        assertEq(namespace.accountOf(localName), address(0), "Username should not be assigned");
        vm.expectRevert(Errors.DoesNotExist.selector);
        namespace.usernameOf(account);
    }

    function test_RemoveUsername() public {
        string memory localName = "satoshi";

        // Create username first
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        assertTrue(namespace.exists(localName), "Username should exist after creation");

        // Remove username
        vm.prank(account);
        namespace.removeUsername({
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassigningRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            removalRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertFalse(namespace.exists(localName), "Username should not exist after removal");
    }

    function test_CannotRemoveUnownedUsername() public {
        string memory localName = "satoshi";
        address otherAccount = makeAddr("OTHER_ACCOUNT");

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Try to remove the username from a different account
        vm.prank(otherAccount);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        namespace.removeUsername({
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassigningRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            removalRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_RemoveAssignedUsername() public {
        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        assertTrue(namespace.exists(localName), "Username should exist after creation");

        // Assign username
        vm.prank(account);
        namespace.assignUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Remove assigned username (should automatically unassign first)
        vm.prank(account);
        namespace.removeUsername({
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassigningRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            removalRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        assertFalse(namespace.exists(localName), "Username should not exist after removal");
    }

    function test_AssignUsername() public {
        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify username exists but is not assigned
        assertTrue(namespace.exists(localName), "Username should exist after creation");
        assertEq(namespace.accountOf(localName), address(0), "Username should not be assigned yet");

        // Assign username
        vm.prank(account);
        namespace.assignUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify username is assigned
        assertEq(namespace.accountOf(localName), account, "Username should be assigned to account");
        assertEq(namespace.usernameOf(account), localName, "Account should have the username");
    }

    function test_CannotAssignNonexistentUsername() public {
        string memory nonexistentName = "nonexistent";
        assertFalse(namespace.exists(nonexistentName), "Username should not exist initially");

        // Try to assign non-existent username
        vm.expectRevert(Errors.DoesNotExist.selector);
        namespace.assignUsername({
            account: account,
            username: nonexistentName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotAssignAlreadyAssignedUsername() public {
        string memory localName = "satoshi";

        // Create username owned by account
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Assign username to account
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
        vm.expectRevert(Errors.RedundantStateChange.selector);
        namespace.assignUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_AutoUnassignPreviousUsername() public {
        string memory firstUsername = "satoshi";
        string memory secondUsername = "vitalik";

        // Create first username owned by account
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: firstUsername,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Create second username owned by account
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: secondUsername,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Assign first username to account
        vm.prank(account);
        namespace.assignUsername({
            account: account,
            username: firstUsername,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify first username is assigned
        assertEq(namespace.accountOf(firstUsername), account, "First username should be assigned to account");
        assertEq(namespace.usernameOf(account), firstUsername, "Account should have the first username");

        // Assign second username to account (should automatically unassign first username)
        vm.prank(account);
        namespace.assignUsername({
            account: account,
            username: secondUsername,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify only second is assigned
        assertEq(namespace.accountOf(firstUsername), address(0), "First username should be unassigned");
        assertEq(namespace.accountOf(secondUsername), account, "Second username should be assigned to account");
        assertEq(namespace.usernameOf(account), secondUsername, "Account should have the second username");
    }

    function test_UnassignUsername() public {
        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Assign username
        vm.prank(account);
        namespace.assignUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify username is assigned
        assertEq(namespace.accountOf(localName), account, "Username should be assigned to account");
        assertEq(namespace.usernameOf(account), localName, "Account should have the username");

        // Unassign username
        vm.prank(account);
        namespace.unassignUsername({
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify username is unassigned
        assertEq(namespace.accountOf(localName), address(0), "Username should be unassigned");
        vm.expectRevert(Errors.DoesNotExist.selector);
        namespace.usernameOf(account);
    }

    function test_CannotUnassign_UnassignedUsername() public {
        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Try to unassign username that is not assigned
        vm.prank(account);
        vm.expectRevert(Errors.RedundantStateChange.selector);
        namespace.unassignUsername({
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_UsernameTokenId() public {
        string memory localName = "satoshi";
        uint256 expectedId = uint256(keccak256(bytes(localName)));

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        assertEq(
            IERC721Namespace(address(namespace)).getTokenIdByUsername(localName),
            expectedId,
            "Token ID should match computed ID"
        );
    }

    function test_TransferUsername() public {
        string memory localName = "satoshi";
        uint256 tokenId = uint256(keccak256(bytes(localName)));
        address otherAccount = makeAddr("OTHER_ACCOUNT");

        // Create and assign username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        assertTrue(namespace.exists(localName), "Username should exist after creation");
        assertEq(LensERC721(address(namespace)).ownerOf(tokenId), account, "Token ownership should be correct");

        vm.prank(account);
        namespace.assignUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Transfer username NFT
        vm.prank(account);
        LensERC721(address(namespace)).transferFrom(account, otherAccount, tokenId);

        // Verify ownership changed but assignment remains
        assertTrue(namespace.exists(localName), "Username should still exist after transfer");
        assertEq(LensERC721(address(namespace)).ownerOf(tokenId), otherAccount, "Token ownership should be transferred");
        assertEq(namespace.accountOf(localName), account, "Username assignment should remain unchanged");
        assertEq(namespace.usernameOf(account), localName, "Account should still have the username");
    }

    function test_CreateAndAssignUsername() public {
        string memory localName = "satoshi";
        uint256 tokenId = uint256(keccak256(bytes(localName)));

        // Create and assign username in one operation
        vm.prank(account);
        Namespace(address(namespace)).createAndAssignUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassigningProcessingParams: _emptyRuleProcessingParamsArray(),
            creationProcessingParams: _emptyRuleProcessingParamsArray(),
            assigningProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify token ownership and username assignment
        assertTrue(namespace.exists(localName), "Username should exist");
        assertEq(LensERC721(address(namespace)).ownerOf(tokenId), account, "Token should be owned by account");
        assertEq(namespace.accountOf(localName), account, "Username should be assigned to account");
        assertEq(namespace.usernameOf(account), localName, "Account should have the username");
    }

    function test_CannotAssignToZeroAddress() public {
        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Try to assign username to zero address
        vm.prank(account);
        vm.expectRevert();
        namespace.assignUsername({
            account: address(0),
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_CannotGetAccountOfEmptyUsername() public {
        vm.expectRevert(Errors.DoesNotExist.selector);
        namespace.accountOf("");
    }

    function test_SetMetadataURI_HasPID(address addressWithPID) public {
        string memory newMetadataURI = "uri://new-metadata-uri";
        assertNotEq(IMetadataBased(address(namespaceForRules)).getMetadataURI(), newMetadataURI);
        mockAccessControl.mockAccess(
            addressWithPID, address(namespaceForRules), uint256(keccak256("lens.permission.SetMetadata")), true
        );
        vm.prank(addressWithPID);
        IMetadataBased(address(namespaceForRules)).setMetadataURI(newMetadataURI);
        assertEq(IMetadataBased(address(namespaceForRules)).getMetadataURI(), newMetadataURI);
    }

    function test_Cannot_SetMetadataURI_IfDoesNotHavePID(address addressWithoutPID) public {
        string memory oldMetadataURI = IMetadataBased(address(namespaceForRules)).getMetadataURI();
        string memory newMetadataURI = "uri://new-metadata-uri";
        assertNotEq(oldMetadataURI, newMetadataURI);
        mockAccessControl.mockAccess(
            addressWithoutPID, address(namespaceForRules), uint256(keccak256("lens.permission.SetMetadata")), false
        );
        vm.prank(addressWithoutPID);
        vm.expectRevert(Errors.AccessDenied.selector);
        IMetadataBased(address(namespaceForRules)).setMetadataURI(newMetadataURI);
        assertEq(IMetadataBased(address(namespaceForRules)).getMetadataURI(), oldMetadataURI);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override(RulesTest, RuleExecutionTest) {
        INamespace(namespaceForRules).changeNamespaceRules(ruleChanges);
    }

    function _primitiveAddress() internal view override returns (address) {
        return namespaceForRules;
    }

    function _aValidRuleSelector() internal pure override returns (bytes4) {
        return INamespaceRule.processCreation.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = INamespaceRule.processCreation.selector;
        selectors[1] = INamespaceRule.processRemoval.selector;
        selectors[2] = INamespaceRule.processAssigning.selector;
        selectors[3] = INamespaceRule.processUnassigning.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return INamespace(namespaceForRules).getNamespaceRules(selector, required);
    }

    function _configureRuleSelector() internal pure override(RulesTest, RuleExecutionTest) returns (bytes4) {
        return INamespaceRule.configure.selector;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testRuleExecution_processCreation(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = INamespaceRule.processCreation.selector;
        string memory username = "satoshi";
        bytes memory executionFunctionCallData = abi.encodeCall(
            INamespace.createUsername,
            (address(this), username, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray(), _emptyKeyValueArray())
        );
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            INamespaceRule.processCreation,
            (bytes32(uint256(1)), address(this), address(this), username, _emptyKeyValueArray(), _emptyKeyValueArray())
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(namespaceForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_processRemoval(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = INamespaceRule.processRemoval.selector;
        string memory username = "satoshi";

        INamespace(namespaceForRules).createUsername({
            account: address(this),
            username: username,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        bytes memory executionFunctionCallData = abi.encodeCall(
            INamespace.removeUsername,
            (username, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray(), _emptyRuleProcessingParamsArray())
        );
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            INamespaceRule.processRemoval,
            (bytes32(uint256(1)), address(this), username, _emptyKeyValueArray(), _emptyKeyValueArray())
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(namespaceForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_processAssigning(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = INamespaceRule.processAssigning.selector;
        string memory username = "satoshi";

        INamespace(namespaceForRules).createUsername({
            account: address(this),
            username: username,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        bytes memory executionFunctionCallData = abi.encodeCall(
            INamespace.assignUsername,
            (
                address(this),
                username,
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray()
            )
        );
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            INamespaceRule.processAssigning,
            (bytes32(uint256(1)), address(this), address(this), username, _emptyKeyValueArray(), _emptyKeyValueArray())
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(namespaceForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_processUnassigning(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = INamespaceRule.processUnassigning.selector;
        string memory username = "satoshi";

        INamespace(namespaceForRules).createUsername({
            account: address(this),
            username: username,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        vm.prank(address(this));
        INamespace(namespaceForRules).assignUsername({
            account: address(this),
            username: username,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        bytes memory executionFunctionCallData = abi.encodeCall(
            INamespace.unassignUsername, (username, _emptyKeyValueArray(), _emptyRuleProcessingParamsArray())
        );
        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            INamespaceRule.processUnassigning,
            (bytes32(uint256(1)), address(this), address(this), username, _emptyKeyValueArray(), _emptyKeyValueArray())
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(namespaceForRules),
            executionFunctionCallData,
            address(this),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function test_UsernameSimpleCharsetNamespaceRule() public {
        // Valid charset
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: "abcdefghijklmnopqrstuvwxyz-0123456789_",
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function _isInCharset(bytes1 char, string memory charset) internal pure returns (bool) {
        for (uint256 i = 0; i < bytes(charset).length; i++) {
            if (char == bytes1(bytes(charset)[i])) {
                return true;
            }
        }
        return false;
    }

    function test_CannotCreateUsername_WithInvalidCharset(bytes1 invalidChar, uint8 charToReplacePosition) public {
        string memory validCharset = "abcdefghijklmnopqrstuvwxyz-0123456789_";
        vm.assume(charToReplacePosition < 38);
        vm.assume(!_isInCharset(invalidChar, validCharset));

        bytes memory invalidUsernameBytes = bytes(validCharset);
        invalidUsernameBytes[charToReplacePosition] = invalidChar;
        string memory invalidUsername = string(invalidUsernameBytes);

        // Invalid charset
        vm.prank(account);
        vm.expectRevert(Errors.RequiredRuleReverted.selector);
        namespace.createUsername({
            account: account,
            username: invalidUsername,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function test_CannotCreateUsername_StartingWithUnderscoreOrDash() public {
        vm.prank(account);
        vm.expectRevert(Errors.RequiredRuleReverted.selector);
        namespace.createUsername({
            account: account,
            username: "_abcdefghijklmnopqrstuvwxyz-0123456789_",
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        vm.prank(account);
        vm.expectRevert(Errors.RequiredRuleReverted.selector);
        namespace.createUsername({
            account: account,
            username: "-abcdefghijklmnopqrstuvwxyz-0123456789_",
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function onERC721Received(
        address, /* operator */
        address, /* from */
        uint256, /* tokenId */
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract NamespaceTestII is BaseDeployments {
    /// @custom:keccak lens.permission.AssignUsername
    uint256 constant PID__ASSIGN_USERNAME = uint256(0x6ed127ecda9c702e81990b9c822ee95d9238c4141f2d4fbaa05c6ba3df0ec6ce);

    INamespace namespace;

    address account = makeAddr("ACCOUNT");
    address namespaceOwner = makeAddr("NAMESPACE_OWNER");

    MockAccessControl mockAccessControl;

    function setUp() public override(BaseDeployments) {
        BaseDeployments.setUp();

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

        mockAccessControl = new MockAccessControl();
    }

    function test_AssignUsername_ToAnotherAccount_ControlledThroughOwnable() public {
        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify username exists but is not assigned
        assertTrue(namespace.exists(localName), "Username should exist after creation");
        assertEq(namespace.accountOf(localName), address(0), "Username should not be assigned yet");

        address ownedAccount = address(new MockOwnable());
        MockOwnable(ownedAccount).mockOwner(account);

        // Assign username
        vm.prank(account);
        namespace.assignUsername({
            account: ownedAccount,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify username is assigned
        assertEq(namespace.accountOf(localName), ownedAccount, "Username should be assigned to account");
        assertEq(namespace.usernameOf(ownedAccount), localName, "Account should have the username");
    }

    function test_AssignUsername_ToAnotherAccount_ControlledThroughAccessControl() public {
        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify username exists but is not assigned
        assertTrue(namespace.exists(localName), "Username should exist after creation");
        assertEq(namespace.accountOf(localName), address(0), "Username should not be assigned yet");

        address controlledAccount = address(new MockAccessControllable());
        MockAccessControllable(controlledAccount).mockAccessControl(mockAccessControl);
        mockAccessControl.mockAccess(account, address(namespace), PID__ASSIGN_USERNAME, true);

        // Assign username
        vm.prank(account);
        namespace.assignUsername({
            account: controlledAccount,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify username is assigned
        assertEq(namespace.accountOf(localName), controlledAccount, "Username should be assigned to account");
        assertEq(namespace.usernameOf(controlledAccount), localName, "Account should have the username");
    }

    function test_Cannot_AssignUsername_ToAnotherAccount_IfEOA(address eoa) public {
        vm.assume(uint160(eoa) > type(uint16).max); // skip system contracts
        vm.assume(eoa.code.length == 0);
        vm.assume(eoa != account);

        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify username exists but is not assigned
        assertTrue(namespace.exists(localName), "Username should exist after creation");
        assertEq(namespace.accountOf(localName), address(0), "Username should not be assigned yet");

        // Assign username
        vm.prank(account);
        vm.expectRevert();
        namespace.assignUsername({
            account: eoa,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_AssignUsername_ToAnotherAccount_OwnedByAnotherAddressButControlledThroughAccessControl(
        address anotherOwner
    ) public {
        vm.assume(anotherOwner != account);

        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify username exists but is not assigned
        assertTrue(namespace.exists(localName), "Username should exist after creation");
        assertEq(namespace.accountOf(localName), address(0), "Username should not be assigned yet");

        // Ownable pattern, but owned by an address different than `account`
        address controlledAccount = address(new MockOwnableAccessControllable());
        MockOwnable(controlledAccount).mockOwner(anotherOwner);
        // However, controlled by `account` through Access Control
        MockAccessControllable(controlledAccount).mockAccessControl(mockAccessControl);
        mockAccessControl.mockAccess(account, address(namespace), PID__ASSIGN_USERNAME, true);

        // Assign username
        vm.prank(account);
        namespace.assignUsername({
            account: controlledAccount,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });

        // Verify username is assigned
        assertEq(namespace.accountOf(localName), controlledAccount, "Username should be assigned to account");
        assertEq(namespace.usernameOf(controlledAccount), localName, "Account should have the username");
    }

    function test_Cannot_AssignUsername_ToAnotherAccount_IfNotControlled(address anotherOwner) public {
        vm.assume(anotherOwner != account);

        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify username exists but is not assigned
        assertTrue(namespace.exists(localName), "Username should exist after creation");
        assertEq(namespace.accountOf(localName), address(0), "Username should not be assigned yet");

        // Ownable pattern, but owned by an address different than `account`
        address controlledAccount = address(new MockOwnableAccessControllable());
        MockOwnable(controlledAccount).mockOwner(anotherOwner);
        // And `account` does not have permissions to assign username.
        MockAccessControllable(controlledAccount).mockAccessControl(mockAccessControl);
        mockAccessControl.mockAccess(account, address(namespace), PID__ASSIGN_USERNAME, false);

        // Assign username
        vm.prank(account);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        namespace.assignUsername({
            account: controlledAccount,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }

    function test_Cannot_AssignUsername_ToAnotherAccount_IfContractButNotFollowingControlPatterns() public {
        string memory localName = "satoshi";

        // Create username
        vm.prank(account);
        namespace.createUsername({
            account: account,
            username: localName,
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        // Verify username exists but is not assigned
        assertTrue(namespace.exists(localName), "Username should exist after creation");
        assertEq(namespace.accountOf(localName), address(0), "Username should not be assigned yet");

        address uncontrolledContract = address(new MockNonOwnableNonAccessControllable());

        // Assign username
        vm.prank(account);
        vm.expectRevert();
        namespace.assignUsername({
            account: uncontrolledContract,
            username: localName,
            customParams: _emptyKeyValueArray(),
            unassignAccountRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            unassignUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray()
        });
    }
}

contract MockOwnable is IOwnable {
    function testMockOwnable() public {
        // Prevents being included in the foundry coverage report
    }

    address internal _owner;

    function transferOwnership(address newOwner) external override {
        _owner = newOwner;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function mockOwner(address newOwner) public {
        _owner = newOwner;
    }
}

contract MockAccessControllable is IAccessControlled {
    function testMockAccessControllable() public {
        // Prevents being included in the foundry coverage report
    }

    IAccessControl internal _accessControl;

    function getAccessControl() external view override returns (IAccessControl) {
        return _accessControl;
    }

    function setAccessControl(IAccessControl accessControl) external {
        _accessControl = accessControl;
    }

    function mockAccessControl(IAccessControl accessControl) public {
        _accessControl = accessControl;
    }
}

contract MockOwnableAccessControllable is MockOwnable, MockAccessControllable {}

contract MockNonOwnableNonAccessControllable {
    function testMockNonOwnableNonAccessControllable() public {
        // Prevents being included in the foundry coverage report
    }

    function foo() external pure returns (uint256) {
        return 69;
    }
}
