// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "./../../helpers/TypeHelpers.sol";
import {
    IAccount,
    AccountManagerPermissions,
    Transaction,
    Allowance,
    AllowanceChange
} from "@extensions/account/IAccount.sol";
import {Account} from "@extensions/account/Account.sol";
import {Feed} from "@core/primitives/feed/Feed.sol";
import {IFeed, Post, CreatePostParams} from "@core/interfaces/IFeed.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {Errors} from "@core/types/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FuzzZkTest} from "test/helpers/FuzzZkTest.sol";

contract AccountTest is FuzzZkTest, BaseDeployments {
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

    function test_AnyManagerCanSpendItsOwnFunds(address someManager, uint256 amount) public {
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

    function test_AnyManagerCanSpendItsOwnFunds_Native(address someManager, uint256 amount) public {
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

    function test_Manager_Cannot_SpendMoreThanHeHasAllowed_FundingHimself(
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

    function test_Manager_Cannot_TreatNftAsCurrencyAndTradeIt(address someManager) public {
        vm.assume(account.isAccountManager(someManager) == false);
        vm.assume(someManager != owner);

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

    function test_ClearAllAllowances_UsingClearAllAllowancesFunction(address someManager, uint256 initialAllowance)
        public
    {
        _setManagerWithoutFundManagementPermission(someManager);

        // Give native GHO allowance
        _increaseAllowance(someManager, address(GHO), initialAllowance);
        // Give WHO allowance
        _increaseAllowance(someManager, address(WGHO), initialAllowance);
        // Give some other currency allowance
        _increaseAllowance(someManager, address(someCurrency), initialAllowance);

        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(someCurrency)));

        assertTrue(account.isAccountManager(someManager));

        address[] memory managers = new address[](1);
        managers[0] = someManager;

        vm.prank(owner);
        account.clearAllAllowances(managers);

        assertTrue(account.isAccountManager(someManager));

        assertEq(0, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(someCurrency)));
    }

    function test_RemovingManager_ClearItsAllowance(address someManager, uint256 initialAllowance) public {
        _setManagerWithoutFundManagementPermission(someManager);

        // Give native GHO allowance
        _increaseAllowance(someManager, address(GHO), initialAllowance);
        // Give WHO allowance
        _increaseAllowance(someManager, address(WGHO), initialAllowance);
        // Give some other currency allowance
        _increaseAllowance(someManager, address(someCurrency), initialAllowance);

        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(someCurrency)));

        assertTrue(account.isAccountManager(someManager));

        vm.prank(owner);
        account.removeAccountManager(someManager);

        assertFalse(account.isAccountManager(someManager));

        assertEq(0, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(someCurrency)));
    }

    function test_EnablingTokenPermissionToManager_MakesAllAllowancesInfinite(address someManager) public {
        _setManagerWithoutFundManagementPermission(someManager);

        // Give native GHO allowance
        _increaseAllowance(someManager, address(GHO), 5 ether);
        // Give some other currency allowance
        _increaseAllowance(someManager, address(someCurrency), 5 ether);

        assertEq(5 ether, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(5 ether, account.getAccountManagerAllowance(someManager, address(someCurrency)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(someNft)));

        vm.prank(owner);
        account.updateAccountManagerPermissions(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: true,
                canTransferTokens: true,
                canTransferNative: true,
                canSetMetadataURI: false
            })
        );

        assertEq(type(uint256).max, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(type(uint256).max, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(type(uint256).max, account.getAccountManagerAllowance(someManager, address(someCurrency)));
        assertEq(type(uint256).max, account.getAccountManagerAllowance(someManager, address(someNft)));
    }

    function test_DisablingPreviouslyEnabledTokenPermissionToManager_ClearsAllAllowances(address someManager) public {
        _setManagerWithoutFundManagementPermission(someManager);

        // Give native GHO allowance
        _increaseAllowance(someManager, address(GHO), 5 ether);
        // Give some other currency allowance
        _increaseAllowance(someManager, address(someCurrency), 5 ether);

        assertEq(5 ether, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(5 ether, account.getAccountManagerAllowance(someManager, address(someCurrency)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(someNft)));

        vm.prank(owner);
        account.updateAccountManagerPermissions(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: true,
                canTransferTokens: true,
                canTransferNative: true,
                canSetMetadataURI: false
            })
        );

        assertEq(type(uint256).max, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(type(uint256).max, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(type(uint256).max, account.getAccountManagerAllowance(someManager, address(someCurrency)));
        assertEq(type(uint256).max, account.getAccountManagerAllowance(someManager, address(someNft)));

        vm.prank(owner);
        account.updateAccountManagerPermissions(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: true,
                canTransferTokens: false,
                canTransferNative: false,
                canSetMetadataURI: false
            })
        );

        assertTrue(account.isAccountManager(someManager));

        assertEq(0, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(someCurrency)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(someNft)));
    }

    function test_IncreasesAllowance_ViaDeposit(address someManager, uint256 amount) public {
        amount = _boundAmount(amount);
        _setManagerWithoutFundManagementPermission(someManager);

        vm.deal(address(account), amount);
        _increaseAllowance(someManager, GHO, amount);

        assertEq(
            account.getAccountManagerAllowance(someManager, address(GHO)),
            amount,
            "GHO allowance wasn't increased to `amount`"
        );
        assertEq(account.getAccountManagerAllowance(someManager, address(WGHO)), 0, "WGHO allowance wasn't 0");

        Transaction[] memory transactions = new Transaction[](1);

        transactions[0] = Transaction({target: address(WGHO), value: amount, data: abi.encodeCall(WGHO.deposit, ())});

        vm.prank(someManager);
        account.executeTransactions(transactions);

        assertEq(account.getAccountManagerAllowance(someManager, address(GHO)), 0, "GHO allowance wasn't decreased to 0");
        assertEq(
            account.getAccountManagerAllowance(someManager, address(WGHO)),
            amount,
            "WGHO allowance wasn't increased to `amount`"
        );
    }

    function test_IncreasesAllowance_ViaWithdraw(address someManager, uint256 amount) public {
        amount = _boundAmount(amount);
        _setManagerWithoutFundManagementPermission(someManager);

        WGHO.mint{value: amount}(address(account), amount);
        _increaseAllowance(someManager, address(WGHO), amount);

        assertEq(
            account.getAccountManagerAllowance(someManager, address(GHO)), 0, "GHO allowance wasn't 0 before deposit()"
        );
        assertEq(
            account.getAccountManagerAllowance(someManager, address(WGHO)),
            amount,
            "WGHO allowance wasn't increased to `amount`"
        );

        vm.prank(someManager);
        account.executeTransaction({target: address(WGHO), value: 0, data: abi.encodeCall(WGHO.withdraw, (amount))});

        assertEq(
            account.getAccountManagerAllowance(someManager, address(GHO)), amount, "GHO allowance wasn't decreased to 0"
        );
        assertEq(
            account.getAccountManagerAllowance(someManager, address(WGHO)), 0, "WGHO allowance wasn't decreased to 0"
        );
    }

    function test_IncreasesAllowance_ViaTransferFrom(address someManager, uint256 amount) public {
        vm.assume(amount > 0);
        _setManagerWithoutFundManagementPermission(someManager);

        someCurrency.mint(someManager, amount);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), 0);

        Transaction[] memory transactions = new Transaction[](1);

        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transferFrom, (someManager, address(account), amount))
        });

        vm.prank(someManager);
        someCurrency.approve(address(account), amount);

        vm.prank(someManager);
        account.executeTransactions(transactions);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), amount);
    }

    function test_SpendAllowance_ViaTransferFrom_FromNotMsgSender_ToAccount(address someManager, uint256 amount)
        public
    {
        vm.assume(amount > 0);
        _setManagerWithoutFundManagementPermission(someManager);

        address newAddress = makeAddr("NEW_ADDRESS");
        someCurrency.mint(newAddress, amount);
        vm.prank(newAddress);
        someCurrency.approve(address(account), amount);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), 0);

        _increaseAllowance(someManager, address(someCurrency), amount);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), amount);

        Transaction[] memory transactions = new Transaction[](1);

        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transferFrom, (newAddress, address(account), amount))
        });

        vm.prank(someManager);
        account.executeTransactions(transactions);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), 0);
    }

    function test_SpendAllowance_ViaTransferFrom_FromMsgSender_ToAccount(address someManager, uint256 amount) public {
        vm.assume(amount > 0);
        _setManagerWithoutFundManagementPermission(someManager);

        address newAddress = makeAddr("NEW_ADDRESS");
        someCurrency.mint(newAddress, amount);
        vm.prank(newAddress);
        someCurrency.approve(address(account), amount);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), 0);

        _increaseAllowance(someManager, address(someCurrency), amount);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), amount);

        Transaction[] memory transactions = new Transaction[](1);

        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transferFrom, (newAddress, address(account), amount))
        });

        vm.prank(someManager);
        account.executeTransactions(transactions);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), 0);
    }

    function test_SpendAllowance_ViaTransferFrom_FromNotMsgSender_ToNotAccount(address someManager, uint256 amount)
        public
    {
        vm.assume(amount > 0);
        _setManagerWithoutFundManagementPermission(someManager);

        address newAddress = makeAddr("NEW_ADDRESS");
        address anotherNewAddress = makeAddr("ANOTHER_NEW_ADDRESS");
        someCurrency.mint(newAddress, amount);
        vm.prank(newAddress);
        someCurrency.approve(address(account), amount);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), 0);

        _increaseAllowance(someManager, address(someCurrency), amount);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), amount);

        Transaction[] memory transactions = new Transaction[](1);

        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transferFrom, (newAddress, address(anotherNewAddress), amount))
        });

        vm.prank(someManager);
        account.executeTransactions(transactions);

        assertEq(account.getAccountManagerAllowance(someManager, address(someCurrency)), 0);
    }

    function test_SpendMoney_AllowanceDecreased_viaDeposit(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend
    ) public {
        initialAllowance = _boundAmount(initialAllowance);
        amountToSpend = bound(amountToSpend, 1, initialAllowance);
        _setManagerWithoutFundManagementPermission(someManager);
        _increaseAllowance(someManager, address(GHO), initialAllowance);

        uint256 allowanceBefore = account.getAccountManagerAllowance(someManager, address(GHO));

        vm.deal(address(account), amountToSpend);

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] =
            Transaction({target: address(WGHO), value: amountToSpend, data: abi.encodeCall(WGHO.deposit, ())});

        vm.prank(someManager);
        account.executeTransactions(transactions);

        uint256 allowanceAfter = account.getAccountManagerAllowance(someManager, address(GHO));

        assertTrue(allowanceAfter < allowanceBefore, "Manager's Allowance does not decrease on deposit()");
        assertEq(
            allowanceAfter,
            allowanceBefore - amountToSpend,
            "Manager's Allowance does not decrease precisely on deposit()"
        );
    }

    function test_SpendMoney_AllowanceDecreased_viaWithdraw(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend
    ) public {
        initialAllowance = _boundAmount(initialAllowance);
        amountToSpend = bound(amountToSpend, 1, initialAllowance);
        _setManagerWithoutFundManagementPermission(someManager);
        _increaseAllowance(someManager, address(WGHO), initialAllowance);

        uint256 allowanceBefore = account.getAccountManagerAllowance(someManager, address(WGHO));

        vm.deal(address(account), amountToSpend);
        vm.startPrank(address(account));
        WGHO.deposit{value: amountToSpend}();
        vm.stopPrank();

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] =
            Transaction({target: address(WGHO), value: 0, data: abi.encodeCall(WGHO.withdraw, (amountToSpend))});

        vm.prank(someManager);
        account.executeTransactions(transactions);

        uint256 allowanceAfter = account.getAccountManagerAllowance(someManager, address(WGHO));

        assertTrue(allowanceAfter < allowanceBefore, "Manager's Allowance does not decrease on withdraw()");
        assertEq(
            allowanceAfter,
            allowanceBefore - amountToSpend,
            "Manager's Allowance does not decrease precisely on withdraw()"
        );
    }

    function test_SpendMoney_AllowanceDecreased_viaApprove(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend,
        address approveTo
    ) public {
        vm.assume(initialAllowance > 0);
        amountToSpend = bound(amountToSpend, 1, initialAllowance);
        _setManagerWithoutFundManagementPermission(someManager);
        _increaseAllowance(someManager, address(someCurrency), initialAllowance);

        uint256 allowanceBefore = account.getAccountManagerAllowance(someManager, address(someCurrency));

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(someCurrency.approve, (approveTo, amountToSpend))
        });

        vm.prank(someManager);
        account.executeTransactions(transactions);

        uint256 allowanceAfter = account.getAccountManagerAllowance(someManager, address(someCurrency));

        assertTrue(allowanceAfter < allowanceBefore, "Manager's Allowance does not decrease on approve()");
        assertEq(
            allowanceAfter,
            allowanceBefore - amountToSpend,
            "Manager's Allowance does not decrease precisely on approve()"
        );
    }

    function test_SpendMoney_AllowanceDecreased_viaIncreaseAllowance(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend,
        address approveTo
    ) public {
        vm.assume(initialAllowance > 0);
        amountToSpend = bound(amountToSpend, 1, initialAllowance);
        _setManagerWithoutFundManagementPermission(someManager);
        _increaseAllowance(someManager, address(someCurrency), initialAllowance);

        uint256 allowanceBefore = account.getAccountManagerAllowance(someManager, address(someCurrency));

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(someCurrency.increaseAllowance, (approveTo, amountToSpend))
        });

        vm.prank(someManager);
        account.executeTransactions(transactions);

        uint256 allowanceAfter = account.getAccountManagerAllowance(someManager, address(someCurrency));

        assertTrue(allowanceAfter < allowanceBefore, "Manager's Allowance does not decrease on approve()");
        assertEq(
            allowanceAfter,
            allowanceBefore - amountToSpend,
            "Manager's Allowance does not decrease precisely on approve()"
        );
    }

    function test_SpendMoney_AllowanceDecreased_viaTransfer(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend,
        address transferTo
    ) public {
        vm.assume(initialAllowance > 0);
        amountToSpend = bound(amountToSpend, 1, initialAllowance);
        _setManagerWithoutFundManagementPermission(someManager);
        _increaseAllowance(someManager, address(someCurrency), initialAllowance);

        uint256 allowanceBefore = account.getAccountManagerAllowance(someManager, address(someCurrency));

        someCurrency.mint(address(account), amountToSpend);

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (transferTo, amountToSpend))
        });

        vm.prank(someManager);
        account.executeTransactions(transactions);

        uint256 allowanceAfter = account.getAccountManagerAllowance(someManager, address(someCurrency));

        assertTrue(allowanceAfter < allowanceBefore, "Manager's Allowance does not decrease on transfer()");
        assertEq(
            allowanceAfter,
            allowanceBefore - amountToSpend,
            "Manager's Allowance does not decrease precisely on transfer()"
        );
    }

    function testCannot_SpendMoreMoneyThanAllowance_viaDeposit(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend
    ) public {
        amountToSpend = _boundAmount(amountToSpend);
        initialAllowance = bound(initialAllowance, 0, amountToSpend - 1);
        _setManagerWithoutFundManagementPermission(someManager);

        if (initialAllowance > 0) {
            _increaseAllowance(someManager, address(GHO), initialAllowance);
        }

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] =
            Transaction({target: address(WGHO), value: amountToSpend, data: abi.encodeCall(WGHO.deposit, ())});

        vm.expectRevert(Errors.InsufficientAllowance.selector);

        vm.prank(someManager);
        account.executeTransactions(transactions);
    }

    function testCannot_SpendMoreMoneyThanAllowance_viaWithdraw(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend
    ) public {
        amountToSpend = _boundAmount(amountToSpend);
        initialAllowance = bound(initialAllowance, 0, amountToSpend - 1);
        _setManagerWithoutFundManagementPermission(someManager);

        if (initialAllowance > 0) {
            _increaseAllowance(someManager, address(WGHO), initialAllowance);
        }

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] =
            Transaction({target: address(WGHO), value: 0, data: abi.encodeCall(WGHO.withdraw, (amountToSpend))});

        vm.expectRevert(Errors.InsufficientAllowance.selector);

        vm.prank(someManager);
        account.executeTransactions(transactions);
    }

    function testCannot_SpendMoreMoneyThanAllowance_viaApprove(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend,
        address approveTo
    ) public {
        vm.assume(amountToSpend > 0);
        initialAllowance = bound(initialAllowance, 0, amountToSpend - 1);
        _setManagerWithoutFundManagementPermission(someManager);

        if (initialAllowance > 0) {
            _increaseAllowance(someManager, address(someCurrency), initialAllowance);
        }

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(someCurrency.approve, (approveTo, amountToSpend))
        });

        vm.expectRevert(Errors.InsufficientAllowance.selector);

        vm.prank(someManager);
        account.executeTransactions(transactions);
    }

    function testCannot_SpendMoreMoneyThanAllowance_viaIncreaseAllowance(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend,
        address approveTo
    ) public {
        vm.assume(amountToSpend > 0);
        initialAllowance = bound(initialAllowance, 0, amountToSpend - 1);
        _setManagerWithoutFundManagementPermission(someManager);

        if (initialAllowance > 0) {
            _increaseAllowance(someManager, address(someCurrency), initialAllowance);
        }

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(someCurrency.increaseAllowance, (approveTo, amountToSpend))
        });

        vm.expectRevert(Errors.InsufficientAllowance.selector);

        vm.prank(someManager);
        account.executeTransactions(transactions);
    }

    function testCannot_SpendMoreMoneyThanAllowance_viaTransfer(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend,
        address transferTo
    ) public {
        vm.assume(amountToSpend > 0);
        initialAllowance = bound(initialAllowance, 0, amountToSpend - 1);
        _setManagerWithoutFundManagementPermission(someManager);

        if (initialAllowance > 0) {
            _increaseAllowance(someManager, address(someCurrency), initialAllowance);
        }

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (transferTo, amountToSpend))
        });

        vm.expectRevert(Errors.InsufficientAllowance.selector);

        vm.prank(someManager);
        account.executeTransactions(transactions);
    }

    function testCannot_SpendMoreMoneyThanAllowance_viaTransferFrom(
        address someManager,
        uint256 initialAllowance,
        uint256 amountToSpend,
        address transferFrom,
        address transferTo
    ) public {
        vm.assume(amountToSpend > 0);
        vm.assume(transferFrom != transferTo);
        vm.assume(transferFrom != address(someManager) && transferTo != address(account));
        initialAllowance = bound(initialAllowance, 0, amountToSpend - 1);
        _setManagerWithoutFundManagementPermission(someManager);

        if (initialAllowance > 0) {
            _increaseAllowance(someManager, address(someCurrency), initialAllowance);
        }

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({
            target: address(someCurrency),
            value: 0,
            data: abi.encodeCall(IERC20.transferFrom, (transferFrom, transferTo, amountToSpend))
        });

        vm.expectRevert(Errors.InsufficientAllowance.selector);

        vm.prank(someManager);
        account.executeTransactions(transactions);
    }

    ///[TEST]/// TODO: ChangeAllowance() function tests:
    ///[TEST]/// TODO: ...

    function test_FundingThroughPlainCall_DoesNotIncreaseAllowance(address someManager) public {
        _setManagerWithoutFundManagementPermission(someManager);

        vm.deal(someManager, 5 ether);

        assertEq(account.getAccountManagerAllowance(someManager, GHO), 0);

        uint256 accountBalanceBefore = address(account).balance;

        vm.prank(someManager);
        (bool success,) = address(account).call{value: 1 ether}("");
        assertTrue(success, "Low-level call failed");

        assertEq(account.getAccountManagerAllowance(someManager, GHO), 0);

        assertEq(accountBalanceBefore + 1 ether, address(account).balance);
    }

    function _increaseAllowance(address toManager, address currency, uint256 byAmount) internal {
        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](1);

        allowanceIncreases[0] = Allowance({currency: currency, byAmount: byAmount});

        allowanceChanges[0] = AllowanceChange({
            spender: toManager,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: new Allowance[](0)
        });

        vm.prank(owner);
        account.changeAllowance(allowanceChanges);
    }

    function _setManagerWithoutFundManagementPermission(address someManager) internal {
        vm.assume(account.isAccountManager(someManager) == false);
        vm.assume(someManager != owner);
        AccountManagerPermissions memory basicPermissionSet = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: false,
            canTransferNative: false,
            canSetMetadataURI: false
        });
        vm.prank(owner);
        account.addAccountManager(someManager, basicPermissionSet);
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
