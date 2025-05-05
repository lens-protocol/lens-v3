// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "./../../helpers/TypeHelpers.sol";
import {IAccount, AccountManagerPermissions, Transaction} from "@extensions/account/IAccount.sol";
import {Account} from "@extensions/account/Account.sol";
import {Feed} from "@core/primitives/feed/Feed.sol";
import {IFeed, Post, CreatePostParams} from "@core/interfaces/IFeed.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {Errors} from "@core/types/Errors.sol";
import {MockCurrency} from "test/mocks/MockCurrency.sol";
import {MockWrapperCurrency} from "test/mocks/MockWrapperCurrency.sol";
import {MockNft} from "test/mocks/MockNft.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract AccountTest is Test, BaseDeployments {
    address owner = makeAddr("OWNER");
    address manager = makeAddr("MANAGER");

    IAccount account;
    IFeed feed;

    function setUp() public override {
        super.setUp();

        address[] memory accountManagers = new address[](1);
        accountManagers[0] = manager;

        AccountManagerPermissions[] memory accountManagersPermissions = new AccountManagerPermissions[](1);
        accountManagersPermissions[0] = AccountManagerPermissions(true, true, true, true);

        account = IAccount(
            payable(
                lensFactory.deployAccount({
                    metadataURI: "uri://account-metadata",
                    owner: owner,
                    accountManagers: accountManagers,
                    accountManagersPermissions: accountManagersPermissions,
                    sourceStamp: _emptySourceStamp(),
                    extraData: _emptyKeyValueArray()
                })
            )
        );

        feed = IFeed(
            lensFactory.deployFeed({
                metadataURI: "some metadata uri",
                owner: address(account),
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        WGHO = new MockWrapperCurrency("Wrapped GHO", "WGHO");
        someCurrency = new MockCurrency("Aave", "AAVE");
        someNft = new MockNft("Milady Maker", "MIL");
    }

    function testCanExecuteTxDirectly() public {
        bytes memory txData = abi.encodeCall(
            Feed.createPost,
            (
                CreatePostParams({
                    author: address(account),
                    contentURI: "some content uri",
                    repostedPostId: 0,
                    quotedPostId: 0,
                    repliedPostId: 0,
                    ruleChanges: _emptyRuleChangeArray(),
                    extraData: _emptyKeyValueArray()
                }),
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray()
            )
        );

        vm.prank(owner);
        bytes memory returnData = account.executeTransaction({target: address(feed), value: 0, data: txData});
        console.log("Return Data length:", returnData.length);
        uint256 postId = abi.decode(returnData, (uint256));

        Post memory post = feed.getPost(postId);
        console.log("Post ContentURI:", post.contentURI);
        console.log("Post Author:", post.author);
    }

    function testCanReceiveAndSendNative(uint256 msgValue) public {
        address anotherAccount = makeAddr("ANOTHER_ACCOUNT");
        vm.assume(msgValue > 0);
        msgValue = msgValue % 1 << 95;
        (bool success,) = anotherAccount.call{value: msgValue}("");
        assertTrue(success, "Low-level call failed");
        assertEq(anotherAccount.balance, msgValue);

        vm.prank(anotherAccount);
        (success,) = address(account).call{value: msgValue}("");
        assertTrue(success, "Low-level call failed");

        assertEq(address(account).balance, msgValue, "Account didn't receive native token");
        assertEq(anotherAccount.balance, 0, "AnotherAccount didn't send native token");

        vm.prank(owner);
        account.executeTransaction({target: anotherAccount, value: 0, data: ""});
        assertEq(anotherAccount.balance, msgValue, "AnotherAccount didn't receive native token");
        assertEq(address(account).balance, 0, "Account didn't send native token");
    }

    function testSendNativeViaManager(uint256 msgValue) public {
        address anotherAccount = makeAddr("ANOTHER_ACCOUNT");
        vm.assume(msgValue > 0);
        msgValue = msgValue % 1 << 95;
        (bool success,) = anotherAccount.call{value: msgValue}("");
        assertTrue(success, "Low-level call failed");
        assertEq(anotherAccount.balance, msgValue);

        vm.prank(anotherAccount);
        (success,) = address(account).call{value: msgValue}("");
        assertTrue(success, "Low-level call failed");
        assertEq(address(account).balance, msgValue, "Account didn't receive native token");
        assertEq(anotherAccount.balance, 0, "AnotherAccount didn't send native token");

        vm.prank(manager);
        account.executeTransaction({target: anotherAccount, value: 0, data: ""});
        assertEq(anotherAccount.balance, msgValue, "AnotherAccount didn't receive native token");
        assertEq(address(account).balance, 0, "Account didn't send native token");
    }

    function testCanExecuteTxViaManager() public {
        bytes memory txData = abi.encodeCall(
            Feed.createPost,
            (
                CreatePostParams({
                    author: address(account),
                    contentURI: "some content uri",
                    repostedPostId: 0,
                    quotedPostId: 0,
                    repliedPostId: 0,
                    ruleChanges: _emptyRuleChangeArray(),
                    extraData: _emptyKeyValueArray()
                }),
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray()
            )
        );

        vm.prank(manager);
        bytes memory returnData = account.executeTransaction({target: address(feed), value: 0, data: txData});
        uint256 postId = abi.decode(returnData, (uint256));

        Post memory post = feed.getPost(postId);
        console.log("Post ContentURI:", post.contentURI);
        console.log("Post Author:", post.author);
    }

    function testCanAddAccountManager(
        address accountManager,
        bool canTransferTokens,
        bool canTransferNative,
        bool canSetMetadataURI
    ) public {
        vm.assume(accountManager != address(0));
        vm.assume(accountManager != owner);
        vm.assume(accountManager != manager);
        vm.assume(canTransferTokens == canTransferNative); // New condition in Account Manager permissions

        vm.prank(owner);
        account.addAccountManager(
            accountManager, AccountManagerPermissions(true, canTransferTokens, canTransferNative, canSetMetadataURI)
        );

        AccountManagerPermissions memory permissions = account.getAccountManagerPermissions(accountManager);
        assertEq(permissions.canExecuteTransactions, true, "canExecuteTransaction assertion failed");
        assertEq(permissions.canTransferTokens, canTransferTokens, "canTransferTokens assertion failed");
        assertEq(permissions.canTransferNative, canTransferNative, "canTransferNative assertion failed");
        assertEq(permissions.canSetMetadataURI, canSetMetadataURI, "canSetMetadataURI assertion failed");
    }

    function testCannotAddAccountManager_Twice() public {
        vm.prank(owner);
        vm.expectRevert(Errors.RedundantStateChange.selector);
        account.addAccountManager(manager, AccountManagerPermissions(true, true, true, true));
    }

    function testCannotAdd_Owner_AsAccountManager() public {
        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.addAccountManager(owner, AccountManagerPermissions(true, true, true, true));
    }

    function testCannotAdd_ZeroAddress_AsManagerTwiceOrWrongly() public {
        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.addAccountManager(address(0), AccountManagerPermissions(true, true, true, true));
    }

    function testCanUpdateAccountManagerPermissions(
        address accountManager,
        bool canTransferTokensBefore,
        bool canTransferNativeBefore,
        bool canSetMetadataURIBefore,
        bool canTransferTokensAfter,
        bool canTransferNativeAfter,
        bool canSetMetadataURIAfter
    ) public {
        vm.assume(accountManager != address(0));
        vm.assume(accountManager != owner);
        vm.assume(accountManager != manager);
        vm.assume(canTransferTokensBefore != canTransferTokensAfter);
        vm.assume(canTransferNativeBefore != canTransferNativeAfter);
        vm.assume(canSetMetadataURIBefore != canSetMetadataURIAfter);
        vm.assume(canTransferTokensBefore == canTransferNativeBefore); // New condition in Account Manager permissions
        vm.assume(canTransferTokensAfter == canTransferNativeAfter); // New condition in Account Manager permissions

        vm.prank(owner);
        account.addAccountManager(
            accountManager,
            AccountManagerPermissions(true, canTransferTokensBefore, canTransferNativeBefore, canSetMetadataURIBefore)
        );

        AccountManagerPermissions memory permissionsBefore = account.getAccountManagerPermissions(accountManager);
        assertEq(permissionsBefore.canExecuteTransactions, true);
        assertEq(permissionsBefore.canTransferTokens, canTransferTokensBefore);
        assertEq(permissionsBefore.canTransferNative, canTransferNativeBefore);
        assertEq(permissionsBefore.canSetMetadataURI, canSetMetadataURIBefore);

        vm.prank(owner);
        account.updateAccountManagerPermissions(
            accountManager,
            AccountManagerPermissions(true, canTransferTokensAfter, canTransferNativeAfter, canSetMetadataURIAfter)
        );

        AccountManagerPermissions memory permissions = account.getAccountManagerPermissions(accountManager);
        assertEq(permissions.canExecuteTransactions, true);
        assertEq(permissions.canTransferTokens, canTransferTokensAfter);
        assertEq(permissions.canTransferNative, canTransferNativeAfter);
        assertEq(permissions.canSetMetadataURI, canSetMetadataURIAfter);
    }

    function testCanRemoveAccountManager(
        address accountManager,
        bool canTransferTokens,
        bool canTransferNative,
        bool canSetMetadataURI
    ) public {
        vm.assume(accountManager != address(0));
        vm.assume(accountManager != owner);
        vm.assume(accountManager != manager);
        vm.assume(canTransferTokens == canTransferNative); // New condition in Account Manager permissions

        vm.prank(owner);
        account.addAccountManager(
            accountManager, AccountManagerPermissions(true, canTransferTokens, canTransferNative, canSetMetadataURI)
        );

        AccountManagerPermissions memory permissionsBefore = account.getAccountManagerPermissions(accountManager);
        assertEq(permissionsBefore.canExecuteTransactions, true, "canExecuteTransactionBefore assertion failed");
        assertEq(permissionsBefore.canTransferTokens, canTransferTokens, "canTransferTokensBefore assertion failed");
        assertEq(permissionsBefore.canTransferNative, canTransferNative, "canTransferNativeBefore assertion failed");
        assertEq(permissionsBefore.canSetMetadataURI, canSetMetadataURI, "canSetMetadataURIBefore assertion failed");

        vm.prank(owner);
        account.removeAccountManager(accountManager);

        AccountManagerPermissions memory permissionsAfter = account.getAccountManagerPermissions(accountManager);
        assertEq(permissionsAfter.canExecuteTransactions, false, "canExecuteTransactionAfter assertion failed");
        assertEq(permissionsAfter.canTransferTokens, false, "canTransferTokensAfter assertion failed");
        assertEq(permissionsAfter.canTransferNative, false, "canTransferNativeAfter assertion failed");
        assertEq(permissionsAfter.canSetMetadataURI, false, "canSetMetadataURIAfter assertion failed");

        assertEq(
            account.canExecuteTransactions(accountManager), false, "canExecuteTransactions function assertion failed"
        );
    }

    function testAccountErrorForwarding() public {
        address errorsTest = address(new ErrorsTest());

        vm.expectRevert("This is an error message");
        vm.prank(owner);
        account.executeTransaction({target: errorsTest, value: 0, data: abi.encodeCall(ErrorsTest.stringError, ())});

        vm.expectRevert(ErrorsTest.CustomError.selector);
        vm.prank(owner);
        account.executeTransaction({target: errorsTest, value: 0, data: abi.encodeCall(ErrorsTest.customError, ())});

        vm.expectRevert(abi.encodeWithSelector(ErrorsTest.CustomErrorWithValue.selector, uint256(123)));
        vm.prank(owner);
        account.executeTransaction({
            target: errorsTest,
            value: 0,
            data: abi.encodeWithSelector(ErrorsTest.customErrorWithValue.selector, uint256(123))
        });
    }

    function test_spending_AnyManagerCanSpendItsOwnFunds(address someManager, uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(account.isAccountManager(someManager) == false);
        vm.assume(someManager != owner);
        someCurrency.mint(someManager, amount);

        AccountManagerPermissions memory basicPermissionSet = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: false,
            canTransferNative: false,
            canSetMetadataURI: false
        });
        vm.prank(owner);
        account.addAccountManager(someManager, basicPermissionSet);

        vm.prank(someManager);
        someCurrency.approve(address(account), amount);

        Transaction[] memory transactions = new Transaction[](2);

        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transferFrom, (someManager, address(account), amount))
        });

        transactions[1] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (someManager, amount))
        });

        vm.prank(someManager);
        account.executeTransactions(transactions);
    }

    function test_spending_AnyManagerCanSpendItsOwnFunds_Native(address someManager, uint256 amount) public {
        address newAddress = makeAddr("NEW_ADDRESS");
        vm.assume(account.isAccountManager(someManager) == false);
        vm.assume(someManager != owner);
        vm.assume(someManager.balance == 0);
        uint256 forGas = 1 ether;
        // Bound msgValue [0, 2^95), as test contract's native balance is 2^96, and vm.deal has issues in zksync foundry
        vm.assume(amount > 0 && amount <= 1 << 95);
        vm.deal(someManager, amount + forGas);

        assertEq(someManager.balance, amount + forGas);
        assertEq(newAddress.balance, 0);

        AccountManagerPermissions memory basicPermissionSet = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: false,
            canTransferNative: false,
            canSetMetadataURI: false
        });
        vm.prank(owner);
        account.addAccountManager(someManager, basicPermissionSet);

        Transaction[] memory transactions = new Transaction[](1);

        transactions[0] = Transaction({target: address(newAddress), value: amount, data: ""});

        vm.prank(someManager);
        account.executeTransactions{value: amount}(transactions);

        assertEq(newAddress.balance, amount);
    }

    function test_spending_Manager_Cannot_SpendMoreThanHeHasAllowed_FundingHimself(
        address someManager,
        uint256 amount,
        uint256 biggerAmount
    ) public {
        vm.assume(account.isAccountManager(someManager) == false);
        vm.assume(someManager != owner);
        vm.assume(amount > 0);
        vm.assume(biggerAmount > amount);
        someCurrency.mint(someManager, amount);

        AccountManagerPermissions memory basicPermissionSet = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: false,
            canTransferNative: false,
            canSetMetadataURI: false
        });
        vm.prank(owner);
        account.addAccountManager(someManager, basicPermissionSet);

        vm.prank(someManager);
        someCurrency.approve(address(account), amount);

        Transaction[] memory transactions = new Transaction[](2);

        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transferFrom, (someManager, address(account), amount))
        });

        transactions[1] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (someManager, biggerAmount))
        });

        vm.prank(someManager);
        vm.expectRevert(Errors.InsufficientAllowance.selector);
        account.executeTransactions(transactions);
    }

    function test_spending_Manager_Cannot_TreatNftAsCurrencyAndTradeIt(address someManager) public {
        vm.assume(account.isAccountManager(someManager) == false);

        AccountManagerPermissions memory basicPermissionSet = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: false,
            canTransferNative: false,
            canSetMetadataURI: false
        });
        vm.prank(owner);
        account.addAccountManager(someManager, basicPermissionSet);

        // Mint super valuable NFT Token ID #1 to the account, it is super valuable!
        someNft.mint(address(account), 1);

        // Mint less relevant NFT Token ID #9999 to the manager
        someNft.mint(someManager, 9999);

        vm.prank(someManager);
        someNft.approve(address(account), 9999);

        Transaction[] memory transactions = new Transaction[](2);

        // Transfer the NFT #9999 to the account, expecting to be treated as ERC-20, then to increase allowance by 9999
        transactions[0] = Transaction({
            target: address(someNft),
            value: 0,
            data: abi.encodeCall(IERC20.transferFrom, (someManager, address(account), 9999))
        });

        // Then, expect to steal/trade the NFT #1 from the account to the manager, given the allowance is expected to
        // be at 9999, then it will just spend 1, succeed and leave allowance decreased to 9998.
        transactions[1] = Transaction({
            target: address(someNft),
            value: 0,
            data: abi.encodeCall(IERC20.transferFrom, (address(account), someManager, 1))
        });

        vm.prank(someManager);
        // Call should fail because it should detect that the target is an ERC-721, not ERC-721, then ask for the
        // specific `canTransferTokens` permission in order to transfer the token.
        vm.expectRevert(Errors.NotAllowed.selector);
        account.executeTransactions(transactions);
    }
}

contract ErrorsTest {
    function testErrorsTest() public {
        // Prevents being included in the foundry coverage report
    }

    function stringError() public pure {
        revert("This is an error message");
    }

    error CustomError();

    function customError() public pure {
        revert CustomError();
    }

    error CustomErrorWithValue(uint256 value);

    function customErrorWithValue(uint256 value) public pure {
        revert CustomErrorWithValue(value);
    }
}
