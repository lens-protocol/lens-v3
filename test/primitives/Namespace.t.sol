// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "@extensions/access/OwnerAdminOnlyAccessControl.sol";
import {INamespace} from "@core/interfaces/INamespace.sol";
import {Namespace} from "@core/primitives/namespace/Namespace.sol";
import {LensUsernameTokenURIProvider} from "@core/primitives/namespace/LensUsernameTokenURIProvider.sol";
import {LensERC721} from "@core/base/LensERC721.sol";
import {Errors} from "@core/types/Errors.sol";
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

        assertEq(namespace.getUsernameTokenId(localName), expectedId, "Token ID should match computed ID");
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
        vm.expectRevert(Errors.InvalidMsgSender.selector);
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
}
