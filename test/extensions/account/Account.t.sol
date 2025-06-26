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
import {IOwnable} from "@core/interfaces/IOwnable.sol";
import {IHarnessAccount, HarnessAccount} from "test/harness/HarnessAccount.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract AccountTestBase is FuzzZkTest, BaseDeployments {
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

    /// Helpers ///

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

    function _assumeCanBeAddedAsManager(address someManager) internal view {
        vm.assume(someManager != address(0));
        vm.assume(someManager != owner);
        vm.assume(account.isAccountManager(someManager) == false);
    }

    function _setManagerWithoutFundManagementPermission(address someManager) internal {
        _assumeCanBeAddedAsManager(someManager);
        AccountManagerPermissions memory basicPermissionSet = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: false,
            canTransferNative: false,
            canSetMetadataURI: false
        });
        vm.prank(owner);
        account.addAccountManager(someManager, basicPermissionSet);
    }

    function _assumeEOA(address someAddress) internal view {
        assumeNotForgeAddress(someAddress);
        vm.assume(someAddress.code.length == 0);
        vm.assume(uint160(someAddress) > type(uint16).max); // skip system contracts
    }
}

contract AccountTest is AccountTestBase {
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
        _assumeCanBeAddedAsManager(accountManager);
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
        _assumeCanBeAddedAsManager(accountManager);
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
        _assumeCanBeAddedAsManager(accountManager);
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
        _assumeCanBeAddedAsManager(someManager);
        vm.assume(amount > 0);
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
        _assumeCanBeAddedAsManager(someManager);
        vm.assume(someManager.balance == 0);
        address newAddress = makeAddr("NEW_ADDRESS");
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
        _assumeCanBeAddedAsManager(someManager);
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
        _assumeCanBeAddedAsManager(someManager);

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
        // SKIPPED: We don't allow to `transferFrom` with `from != msg.sender` until EIP-7702 is supported by ZkSync.
        vm.skip(true);

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

    function test_Cannot_SpendAllowance_ViaTransferFrom_FromNotMsgSender_ToAccount(address someManager, uint256 amount)
        public
    {
        // Tweaked from the SKIPPED test `test_SpendAllowance_ViaTransferFrom_FromNotMsgSender_ToAccount`.
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
        vm.expectRevert(Errors.NotAllowed.selector);
        account.executeTransactions(transactions);
    }

    function test_SpendAllowance_ViaTransferFrom_FromMsgSender_ToAccount(address someManager, uint256 amount) public {
        // SKIPPED: We don't allow to `transferFrom` with `from != msg.sender` until EIP-7702 is supported by ZkSync.
        vm.skip(true);

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
        // SKIPPED: We don't allow to `transferFrom` with `from != msg.sender` until EIP-7702 is supported by ZkSync.
        vm.skip(true);

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

    function test_Cannot_SpendAllowance_ViaTransferFrom_FromNotMsgSender_ToNotAccount(
        address someManager,
        uint256 amount
    ) public {
        // Tweaked from the SKIPPED test `test_SpendAllowance_ViaTransferFrom_FromNotMsgSender_ToNotAccount`.

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
        vm.expectRevert(Errors.NotAllowed.selector);
        account.executeTransactions(transactions);
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
        vm.assume(approveTo != address(0));
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
        vm.assume(approveTo != address(0));
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
        vm.assume(transferTo != address(0));
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
}

contract AccountTest2 is AccountTestBase {
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
        // SKIPPED: We don't allow to `transferFrom` with `from != msg.sender` until EIP-7702 is supported by ZkSync.
        vm.skip(true);

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

    function test_ChangeAllowance_IncreaseAllowance(address someManager, uint256 byAmount) public {
        byAmount = _boundAmount(byAmount);
        _setManagerWithoutFundManagementPermission(someManager);

        assertEq(0, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(someCurrency)));

        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](3);
        Allowance[] memory allowanceDecreases = new Allowance[](0);

        allowanceIncreases[0] = Allowance({currency: address(GHO), byAmount: byAmount});
        allowanceIncreases[1] = Allowance({currency: address(WGHO), byAmount: byAmount});
        allowanceIncreases[2] = Allowance({currency: address(someCurrency), byAmount: byAmount});

        allowanceChanges[0] = AllowanceChange({
            spender: someManager,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        account.changeAllowance(allowanceChanges);

        assertEq(byAmount, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(byAmount, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(byAmount, account.getAccountManagerAllowance(someManager, address(someCurrency)));

        allowanceIncreases[0] = Allowance({currency: address(GHO), byAmount: 1});
        allowanceIncreases[1] = Allowance({currency: address(WGHO), byAmount: 2});
        allowanceIncreases[2] = Allowance({currency: address(someCurrency), byAmount: 3});

        allowanceChanges[0] = AllowanceChange({
            spender: someManager,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        account.changeAllowance(allowanceChanges);

        assertEq(byAmount + 1, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(byAmount + 2, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(byAmount + 3, account.getAccountManagerAllowance(someManager, address(someCurrency)));
    }

    function test_ChangeAllowance_DecreaseAllowance(address someManager, uint256 initialAllowance, uint256 byAmount)
        public
    {
        initialAllowance = _boundAmount(initialAllowance);
        vm.assume(byAmount <= initialAllowance);
        _setManagerWithoutFundManagementPermission(someManager);

        assertEq(0, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(someCurrency)));

        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](3);
        Allowance[] memory allowanceDecreases = new Allowance[](3);

        allowanceIncreases[0] = Allowance({currency: address(GHO), byAmount: initialAllowance});
        allowanceIncreases[1] = Allowance({currency: address(WGHO), byAmount: initialAllowance});
        allowanceIncreases[2] = Allowance({currency: address(someCurrency), byAmount: initialAllowance});

        allowanceChanges[0] = AllowanceChange({
            spender: someManager,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: new Allowance[](0)
        });

        vm.prank(owner);
        account.changeAllowance(allowanceChanges);

        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(someCurrency)));

        allowanceDecreases[0] = Allowance({currency: address(GHO), byAmount: byAmount});
        allowanceDecreases[1] = Allowance({currency: address(WGHO), byAmount: byAmount});
        allowanceDecreases[2] = Allowance({currency: address(someCurrency), byAmount: byAmount});

        allowanceChanges[0] = AllowanceChange({
            spender: someManager,
            allowanceIncreases: new Allowance[](0),
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        account.changeAllowance(allowanceChanges);

        assertEq(initialAllowance - byAmount, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(initialAllowance - byAmount, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(initialAllowance - byAmount, account.getAccountManagerAllowance(someManager, address(someCurrency)));
    }

    function test_ChangeAllowance_DecreaseAllowance_DoesNotFailWithUnderflow(
        address someManager,
        uint256 initialAllowance,
        uint256 byAmount
    ) public {
        initialAllowance = _boundAmount(initialAllowance);
        vm.assume(byAmount > initialAllowance);
        _setManagerWithoutFundManagementPermission(someManager);

        assertEq(0, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(someCurrency)));

        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](3);
        Allowance[] memory allowanceDecreases = new Allowance[](3);

        allowanceIncreases[0] = Allowance({currency: address(GHO), byAmount: initialAllowance});
        allowanceIncreases[1] = Allowance({currency: address(WGHO), byAmount: initialAllowance});
        allowanceIncreases[2] = Allowance({currency: address(someCurrency), byAmount: initialAllowance});

        allowanceChanges[0] = AllowanceChange({
            spender: someManager,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: new Allowance[](0)
        });

        vm.prank(owner);
        account.changeAllowance(allowanceChanges);

        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(someCurrency)));

        allowanceDecreases[0] = Allowance({currency: address(GHO), byAmount: byAmount});
        allowanceDecreases[1] = Allowance({currency: address(WGHO), byAmount: byAmount});
        allowanceDecreases[2] = Allowance({currency: address(someCurrency), byAmount: byAmount});

        allowanceChanges[0] = AllowanceChange({
            spender: someManager,
            allowanceIncreases: new Allowance[](0),
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        account.changeAllowance(allowanceChanges);

        assertEq(0, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(0, account.getAccountManagerAllowance(someManager, address(someCurrency)));
    }

    function test_ChangeAllowance_IncreaseAllowance_FailsIfCanTransferTokensEnabled(uint256 byAmount) public {
        byAmount = _boundAmount(byAmount);

        assertTrue(account.getAccountManagerPermissions(manager).canTransferTokens);

        assertEq(type(uint256).max, account.getAccountManagerAllowance(manager, address(GHO)));
        assertEq(type(uint256).max, account.getAccountManagerAllowance(manager, address(WGHO)));
        assertEq(type(uint256).max, account.getAccountManagerAllowance(manager, address(someCurrency)));

        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](3);
        Allowance[] memory allowanceDecreases = new Allowance[](0);

        allowanceIncreases[0] = Allowance({currency: address(GHO), byAmount: byAmount});
        allowanceIncreases[1] = Allowance({currency: address(WGHO), byAmount: byAmount});
        allowanceIncreases[2] = Allowance({currency: address(someCurrency), byAmount: byAmount});

        allowanceChanges[0] = AllowanceChange({
            spender: manager,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        vm.expectRevert(Errors.RedundantStateChange.selector);
        account.changeAllowance(allowanceChanges);
    }

    function test_ChangeAllowance_DecreaseAllowance_FailsIfCanTransferTokensEnabled(uint256 byAmount) public {
        byAmount = _boundAmount(byAmount);

        assertTrue(account.getAccountManagerPermissions(manager).canTransferTokens);

        assertEq(type(uint256).max, account.getAccountManagerAllowance(manager, address(GHO)));
        assertEq(type(uint256).max, account.getAccountManagerAllowance(manager, address(WGHO)));
        assertEq(type(uint256).max, account.getAccountManagerAllowance(manager, address(someCurrency)));

        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](0);
        Allowance[] memory allowanceDecreases = new Allowance[](3);

        allowanceDecreases[0] = Allowance({currency: address(GHO), byAmount: byAmount});
        allowanceDecreases[1] = Allowance({currency: address(WGHO), byAmount: byAmount});
        allowanceDecreases[2] = Allowance({currency: address(someCurrency), byAmount: byAmount});

        allowanceChanges[0] = AllowanceChange({
            spender: manager,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.changeAllowance(allowanceChanges);
    }

    function test_ChangeAllowance_CanSetSpecificAllowance_WithoutKnowingCurrentAllowance(
        address someManager,
        uint256 initialAllowance,
        uint256 desiredAllowance
    ) public {
        initialAllowance = _boundAmount(initialAllowance);
        desiredAllowance = _boundAmount(desiredAllowance);
        _setManagerWithoutFundManagementPermission(someManager);
        _increaseAllowance(someManager, address(GHO), initialAllowance);
        _increaseAllowance(someManager, address(WGHO), initialAllowance);
        _increaseAllowance(someManager, address(someCurrency), initialAllowance);

        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(initialAllowance, account.getAccountManagerAllowance(someManager, address(someCurrency)));

        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](3);
        Allowance[] memory allowanceDecreases = new Allowance[](3);

        allowanceDecreases[0] = Allowance({currency: address(GHO), byAmount: type(uint256).max});
        allowanceDecreases[1] = Allowance({currency: address(WGHO), byAmount: type(uint256).max});
        allowanceDecreases[2] = Allowance({currency: address(someCurrency), byAmount: type(uint256).max});

        allowanceIncreases[0] = Allowance({currency: address(GHO), byAmount: desiredAllowance});
        allowanceIncreases[1] = Allowance({currency: address(WGHO), byAmount: desiredAllowance});
        allowanceIncreases[2] = Allowance({currency: address(someCurrency), byAmount: desiredAllowance});

        allowanceChanges[0] = AllowanceChange({
            spender: someManager,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        account.changeAllowance(allowanceChanges);

        assertEq(desiredAllowance, account.getAccountManagerAllowance(someManager, address(GHO)));
        assertEq(desiredAllowance, account.getAccountManagerAllowance(someManager, address(WGHO)));
        assertEq(desiredAllowance, account.getAccountManagerAllowance(someManager, address(someCurrency)));
    }

    function test_ChangeAllowance_IncreaseAllowance_FailsOnTheOwner(uint256 byAmount) public {
        byAmount = _boundAmount(byAmount);

        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](3);
        Allowance[] memory allowanceDecreases = new Allowance[](0);

        allowanceIncreases[0] = Allowance({currency: address(GHO), byAmount: byAmount});
        allowanceIncreases[1] = Allowance({currency: address(WGHO), byAmount: byAmount});
        allowanceIncreases[2] = Allowance({currency: address(someCurrency), byAmount: byAmount});

        allowanceChanges[0] = AllowanceChange({
            spender: owner,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.changeAllowance(allowanceChanges);
    }

    function test_ChangeAllowance_DecreaseAllowance_FailsOnTheOwner(uint256 byAmount) public {
        byAmount = _boundAmount(byAmount);

        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](0);
        Allowance[] memory allowanceDecreases = new Allowance[](3);

        allowanceDecreases[0] = Allowance({currency: address(GHO), byAmount: byAmount});
        allowanceDecreases[1] = Allowance({currency: address(WGHO), byAmount: byAmount});
        allowanceDecreases[2] = Allowance({currency: address(someCurrency), byAmount: byAmount});

        allowanceChanges[0] = AllowanceChange({
            spender: owner,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.changeAllowance(allowanceChanges);
    }

    function test_ChangeAllowance_IncreaseAllowance_FailsOnNonManagers(address nonManager, uint256 byAmount) public {
        byAmount = _boundAmount(byAmount);
        vm.assume(account.isAccountManager(nonManager) == false);

        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](3);
        Allowance[] memory allowanceDecreases = new Allowance[](0);

        allowanceIncreases[0] = Allowance({currency: address(GHO), byAmount: byAmount});
        allowanceIncreases[1] = Allowance({currency: address(WGHO), byAmount: byAmount});
        allowanceIncreases[2] = Allowance({currency: address(someCurrency), byAmount: byAmount});

        allowanceChanges[0] = AllowanceChange({
            spender: nonManager,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.changeAllowance(allowanceChanges);
    }

    function test_ChangeAllowance_DecreaseAllowance_FailsOnNonManagers(address nonManager, uint256 byAmount) public {
        byAmount = _boundAmount(byAmount);
        vm.assume(account.isAccountManager(nonManager) == false);

        AllowanceChange[] memory allowanceChanges = new AllowanceChange[](1);
        Allowance[] memory allowanceIncreases = new Allowance[](0);
        Allowance[] memory allowanceDecreases = new Allowance[](3);

        allowanceDecreases[0] = Allowance({currency: address(GHO), byAmount: byAmount});
        allowanceDecreases[1] = Allowance({currency: address(WGHO), byAmount: byAmount});
        allowanceDecreases[2] = Allowance({currency: address(someCurrency), byAmount: byAmount});

        allowanceChanges[0] = AllowanceChange({
            spender: nonManager,
            allowanceIncreases: allowanceIncreases,
            allowanceDecreases: allowanceDecreases
        });

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.changeAllowance(allowanceChanges);
    }

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

    function test_isAccountManager_TrueForManager(
        address managerWithExecuteTransactions,
        address managerWithSetMetadataURI,
        address otherAddress,
        bool canTransferTokens
    ) public {
        vm.assume(managerWithExecuteTransactions != managerWithSetMetadataURI);
        vm.assume(managerWithExecuteTransactions != otherAddress);
        vm.assume(managerWithSetMetadataURI != otherAddress);
        _assumeCanBeAddedAsManager(managerWithExecuteTransactions);
        _assumeCanBeAddedAsManager(managerWithSetMetadataURI);
        _assumeCanBeAddedAsManager(otherAddress);

        vm.prank(owner);
        account.addAccountManager(
            managerWithExecuteTransactions,
            AccountManagerPermissions({
                canExecuteTransactions: true,
                canTransferTokens: canTransferTokens,
                canTransferNative: canTransferTokens,
                canSetMetadataURI: false
            })
        );
        assertTrue(
            account.isAccountManager(managerWithExecuteTransactions),
            "Manager with execute transactions permission is an account manager"
        );
        assertFalse(account.isAccountManager(otherAddress), "Other address is not an account manager");

        vm.prank(owner);
        account.addAccountManager(
            managerWithSetMetadataURI,
            AccountManagerPermissions({
                canExecuteTransactions: false,
                canTransferTokens: false,
                canTransferNative: false,
                canSetMetadataURI: true
            })
        );
        assertTrue(
            account.isAccountManager(managerWithSetMetadataURI),
            "Manager with set metadata URI permission is an account manager"
        );
        assertFalse(account.isAccountManager(otherAddress), "Other address is not an account manager");
    }

    function test_canExecuteTransactions_TrueForOwner() public view {
        assertTrue(account.canExecuteTransactions(owner), "Owner can execute transactions");
    }

    function test_canExecuteTransactions_TrueForManagerWithPermission(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);
        _setManagerWithoutFundManagementPermission(someManager);
        assertTrue(account.canExecuteTransactions(someManager), "Manager with permission can execute transactions");
    }

    function test_canExecuteTransactions_FalseForManagerWithoutPermission(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);

        vm.prank(owner);
        account.addAccountManager(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: false,
                canTransferTokens: false,
                canTransferNative: false,
                canSetMetadataURI: true
            })
        );
        assertFalse(
            account.canExecuteTransactions(someManager), "Manager without permission cannot execute transactions"
        );
    }

    function test_canExecuteTransactions_FalseForRemovedManager(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);

        vm.prank(owner);
        account.addAccountManager(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: true,
                canTransferTokens: true,
                canTransferNative: true,
                canSetMetadataURI: true
            })
        );
        assertTrue(account.canExecuteTransactions(someManager), "Manager with permission can execute transactions");

        vm.prank(owner);
        account.removeAccountManager(someManager);
        assertFalse(
            account.canExecuteTransactions(someManager), "Manager without permission cannot execute transactions"
        );
    }

    function test_canSetMetadataURI_TrueForOwner() public view {
        assertTrue(account.canSetMetadataURI(owner), "Owner can set metadataURI");
    }

    function test_canSetMetadataURI_TrueForManagerWithPermission(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);
        vm.prank(owner);
        account.addAccountManager(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: false,
                canTransferTokens: false,
                canTransferNative: false,
                canSetMetadataURI: true
            })
        );
        assertTrue(account.canSetMetadataURI(someManager), "Manager with permission can set metadataURI");
    }

    function test_canSetMetadataURI_FalseForManagerWithoutPermission(address someManager, bool canTransferTokens)
        public
    {
        _assumeCanBeAddedAsManager(someManager);
        AccountManagerPermissions memory permissions = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: canTransferTokens,
            canTransferNative: canTransferTokens,
            canSetMetadataURI: false
        });
        vm.prank(owner);
        account.addAccountManager(someManager, permissions);
        assertFalse(account.canSetMetadataURI(someManager), "Manager without permission cannot set metadataURI");
    }

    function test_canSetMetadataURI_FalseForRemovedManager(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);

        vm.prank(owner);
        account.addAccountManager(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: false,
                canTransferTokens: false,
                canTransferNative: false,
                canSetMetadataURI: true
            })
        );
        assertTrue(account.canSetMetadataURI(someManager), "Manager with permission can set metadataURI");

        vm.prank(owner);
        account.removeAccountManager(someManager);
        assertFalse(account.canSetMetadataURI(someManager), "Removed manager cannot set metadataURI");
    }

    function test_canSetMetadataURI_FalseForRandomAddress(address randomAddress) public view {
        vm.assume(randomAddress != owner);
        vm.assume(account.isAccountManager(randomAddress) == false);

        assertFalse(account.canSetMetadataURI(randomAddress), "Random address cannot set metadataURI");
    }

    function test_setMetadataURI_IfOwner() public {
        assertEq(IOwnable(address(account)).owner(), owner);
        string memory metadataURI = "uri://new-metadata";

        vm.expectEmit(true, true, true, true);
        emit IAccount.Lens_Account_MetadataURISet(metadataURI, address(0));

        vm.prank(owner);
        account.setMetadataURI(metadataURI, _emptySourceStamp());
        assertEq(account.getMetadataURI(), metadataURI);
    }

    function test_setMetadataURI_IfManagerWithFullPermission(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);
        vm.prank(owner);
        account.addAccountManager(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: true,
                canTransferTokens: true,
                canTransferNative: true,
                canSetMetadataURI: true
            })
        );

        string memory metadataURI = "uri://new-metadata";

        vm.prank(manager);
        account.setMetadataURI(metadataURI, _emptySourceStamp());
        assertEq(account.getMetadataURI(), metadataURI);
    }

    function test_setMetadataURI_IfManagerWithSetMetadataURIPermission(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);
        vm.prank(owner);
        account.addAccountManager(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: false,
                canTransferTokens: false,
                canTransferNative: false,
                canSetMetadataURI: true
            })
        );

        string memory metadataURI = "uri://new-metadata";

        vm.prank(someManager);
        account.setMetadataURI(metadataURI, _emptySourceStamp());
        assertEq(account.getMetadataURI(), metadataURI);
    }

    function testCannot_setMetadataURI_IfManagerWithoutPermission(address someManager, bool canTransfer) public {
        _assumeCanBeAddedAsManager(someManager);

        string memory metadataURI = "uri://new-metadata";

        AccountManagerPermissions memory permissions = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: canTransfer,
            canTransferNative: canTransfer,
            canSetMetadataURI: false
        });

        vm.prank(owner);
        account.addAccountManager(someManager, permissions);

        vm.prank(someManager);
        vm.expectRevert(Errors.NotAllowed.selector);
        account.setMetadataURI(metadataURI, _emptySourceStamp());
    }

    function testCannot_setMetadataURI_IfManagerRemoved(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);

        string memory metadataURI = "uri://new-metadata-for-manager";

        AccountManagerPermissions memory permissions = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: true,
            canTransferNative: true,
            canSetMetadataURI: true
        });

        vm.prank(owner);
        account.addAccountManager(someManager, permissions);

        vm.prank(someManager);
        account.setMetadataURI(metadataURI, _emptySourceStamp());
        assertEq(account.getMetadataURI(), metadataURI);

        vm.prank(owner);
        account.removeAccountManager(someManager);

        vm.prank(someManager);
        vm.expectRevert(Errors.NotAllowed.selector);
        account.setMetadataURI(metadataURI, _emptySourceStamp());
    }

    function test_getExtraData_ReturnValidData() public {
        KeyValue memory data = KeyValue({key: keccak256("test.key"), value: abi.encode("test value")});

        vm.expectEmit(true, true, true, true);
        emit IAccount.Lens_Account_ExtraDataAdded(data.key, data.value, data.value);

        vm.prank(owner);
        account.setExtraData(_toKeyValueArray(data));
        assertEq(account.getExtraData(data.key), data.value);
    }

    function test_setExtraData_OnlyOwner() public {
        KeyValue memory extraData = KeyValue({key: keccak256("test.key"), value: abi.encode("test value")});

        assertEq(account.getExtraData(extraData.key).length, 0);

        vm.prank(owner);
        account.setExtraData(_toKeyValueArray(extraData));
        assertEq(account.getExtraData(extraData.key), extraData.value);
    }

    function testCannot_setExtraData_IfNotOwner(address notOwner) public {
        vm.assume(notOwner != owner);

        KeyValue memory extraData = KeyValue({key: keccak256("test.key"), value: abi.encode("test value")});

        assertEq(account.getExtraData(extraData.key).length, 0);

        vm.prank(notOwner);
        vm.expectRevert();
        account.setExtraData(_toKeyValueArray(extraData));
    }

    function test_setExtraData_CanUpdateExtraData() public {
        bytes32 testKey = keccak256("test.key");
        bytes memory initialValue = abi.encode("initial value");
        bytes memory updatedValue = abi.encode("updated value");

        KeyValue memory initialData = KeyValue({key: testKey, value: initialValue});
        assertEq(account.getExtraData(testKey).length, 0);

        vm.prank(owner);
        account.setExtraData(_toKeyValueArray(initialData));
        assertEq(account.getExtraData(initialData.key), initialValue);

        KeyValue memory updatedData = KeyValue({key: testKey, value: updatedValue});

        vm.expectEmit(true, true, true, true);
        emit IAccount.Lens_Account_ExtraDataUpdated(testKey, updatedValue, updatedValue);

        vm.prank(owner);
        account.setExtraData(_toKeyValueArray(updatedData));
        assertEq(account.getExtraData(testKey), updatedValue);
    }

    function test_setExtraData_CanRemoveExtraData() public {
        bytes32 testKey = keccak256("test.key");
        bytes memory testValue = abi.encode("test value");

        KeyValue memory initialData = KeyValue({key: testKey, value: testValue});
        vm.prank(owner);
        account.setExtraData(_toKeyValueArray(initialData));
        assertEq(account.getExtraData(initialData.key), initialData.value);

        KeyValue memory removeData = KeyValue({key: testKey, value: ""});

        vm.expectEmit(true, true, true, true);
        emit IAccount.Lens_Account_ExtraDataRemoved(testKey);

        vm.prank(owner);
        account.setExtraData(_toKeyValueArray(removeData));
        assertEq(account.getExtraData(testKey).length, 0);
    }

    function test_setExtraData_CanSetMultipleData() public {
        KeyValue memory kv1 = KeyValue({key: keccak256("key1"), value: abi.encode("value1")});
        KeyValue memory kv2 = KeyValue({key: keccak256("key2"), value: abi.encode("value2")});
        KeyValue memory kv3 = KeyValue({key: keccak256("key3"), value: abi.encode("value3")});

        vm.prank(owner);
        account.setExtraData(_toKeyValueArray(kv1, kv2, kv3));

        assertEq(account.getExtraData(keccak256("key1")), abi.encode("value1"));
        assertEq(account.getExtraData(keccak256("key2")), abi.encode("value2"));
        assertEq(account.getExtraData(keccak256("key3")), abi.encode("value3"));
    }

    function test_transferOwnership(address newOwner) public {
        vm.assume(newOwner != owner);
        vm.assume(newOwner != address(0));

        vm.expectRevert();
        IOwnable(address(account)).transferOwnership(newOwner);

        vm.expectEmit(true, true, true, true);
        emit IAccount.Lens_Account_OwnershipTransferred(owner, newOwner);

        vm.prank(owner);
        IOwnable(address(account)).transferOwnership(newOwner);
        assertEq(IOwnable(address(account)).owner(), newOwner);
    }

    function test_transferOwnership_RemoveManagerIfSameAsOwner(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);

        vm.prank(owner);
        account.addAccountManager(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: true,
                canTransferTokens: true,
                canTransferNative: true,
                canSetMetadataURI: true
            })
        );
        assertTrue(account.isAccountManager(someManager));

        vm.prank(owner);
        IOwnable(address(account)).transferOwnership(someManager);

        assertEq(IOwnable(address(account)).owner(), someManager);
        assertFalse(account.isAccountManager(someManager));
    }

    function testCannot_transferOwnership_IfNotOwner(address notOwner) public {
        vm.assume(notOwner != owner);

        vm.prank(notOwner);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        IOwnable(address(account)).transferOwnership(notOwner);
    }

    function testCannot_transferOwnership_IfManagerWithFullPermission(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);

        vm.prank(owner);
        account.addAccountManager(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: true,
                canTransferTokens: true,
                canTransferNative: true,
                canSetMetadataURI: true
            })
        );
        assertTrue(account.isAccountManager(someManager));

        vm.prank(someManager);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        IOwnable(address(account)).transferOwnership(someManager);
    }

    function testCannot_addAccountManager_IfWrongPermissions(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);

        AccountManagerPermissions memory canTransferTokensPermissions = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: false,
            canTransferNative: true,
            canSetMetadataURI: true
        });

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.addAccountManager(someManager, canTransferTokensPermissions);

        AccountManagerPermissions memory canTransferNativePermissions = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: true,
            canTransferNative: false,
            canSetMetadataURI: true
        });

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.addAccountManager(someManager, canTransferNativePermissions);

        AccountManagerPermissions memory transferWithoutExecuteTransactionsPermission = AccountManagerPermissions({
            canExecuteTransactions: false,
            canTransferTokens: true,
            canTransferNative: true,
            canSetMetadataURI: true
        });

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.addAccountManager(someManager, transferWithoutExecuteTransactionsPermission);

        AccountManagerPermissions memory equalTransferWithoutExecuteTransactionsAndSetMetadataURIPermission =
        AccountManagerPermissions({
            canExecuteTransactions: false,
            canTransferTokens: true,
            canTransferNative: true,
            canSetMetadataURI: false
        });

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.addAccountManager(someManager, equalTransferWithoutExecuteTransactionsAndSetMetadataURIPermission);

        AccountManagerPermissions memory withoutPermissions = AccountManagerPermissions({
            canExecuteTransactions: false,
            canTransferTokens: false,
            canTransferNative: false,
            canSetMetadataURI: false
        });

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.addAccountManager(someManager, withoutPermissions);
    }

    function test_executeTransactions_IfOwner(address target, uint256 amount, bytes4 selector) public {
        _assumeEOA(target);
        amount = _boundAmountAllowZero(amount);
        if (amount > 0) {
            vm.deal(address(account), amount);
        }

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({target: target, value: amount, data: abi.encode(selector)});

        vm.prank(owner);
        account.executeTransactions(transactions);
    }

    function test_executeTransactions_IfManagerWithFullPermission(
        address someManager,
        address target,
        uint256 amount,
        bytes4 selector
    ) public {
        _assumeEOA(target);
        amount = _boundAmountAllowZero(amount);
        if (amount > 0) {
            vm.deal(address(account), amount);
        }

        _assumeCanBeAddedAsManager(someManager);

        vm.prank(owner);
        account.addAccountManager(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: true,
                canTransferTokens: true,
                canTransferNative: true,
                canSetMetadataURI: true
            })
        );

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({target: target, value: amount, data: abi.encode(selector)});

        vm.prank(someManager);
        account.executeTransactions(transactions);
    }

    function testCannot_executeTransactions_IfManagerWithoutPermission(
        address someManager,
        address target,
        uint256 amount,
        bytes4 selector
    ) public {
        _assumeEOA(target);
        amount = _boundAmountAllowZero(amount);
        if (amount > 0) {
            vm.deal(address(account), amount);
        }

        _assumeCanBeAddedAsManager(someManager);

        vm.prank(owner);
        account.addAccountManager(
            someManager,
            AccountManagerPermissions({
                canExecuteTransactions: false,
                canTransferTokens: false,
                canTransferNative: false,
                canSetMetadataURI: true
            })
        );

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({target: target, value: amount, data: abi.encode(selector)});

        vm.prank(someManager);
        vm.expectRevert(Errors.NotAllowed.selector);
        account.executeTransactions(transactions);
    }

    function testCannot_executeTransactions_IfRandomAddress(
        address randomAddress,
        address target,
        uint256 amount,
        bytes4 selector
    ) public {
        _assumeEOA(target);
        amount = _boundAmountAllowZero(amount);
        if (amount > 0) {
            vm.deal(address(account), amount);
        }

        vm.assume(randomAddress != owner);
        vm.assume(account.isAccountManager(randomAddress) == false);

        Transaction[] memory transactions = new Transaction[](1);
        transactions[0] = Transaction({target: target, value: amount, data: abi.encode(selector)});

        vm.prank(randomAddress);
        vm.expectRevert(Errors.NotAllowed.selector);
        account.executeTransactions(transactions);
    }
}

contract AccountTest3 is AccountTestBase {
    function test_updateAccountManagerPermissions_OnlyOwner(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);

        _setManagerWithoutFundManagementPermission(someManager);

        AccountManagerPermissions memory updatePermissions = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: true,
            canTransferNative: true,
            canSetMetadataURI: true
        });

        vm.prank(owner);
        account.updateAccountManagerPermissions(someManager, updatePermissions);

        AccountManagerPermissions memory newPermissions = account.getAccountManagerPermissions(someManager);
        assertEq(updatePermissions.canExecuteTransactions, newPermissions.canExecuteTransactions);
        assertEq(updatePermissions.canTransferTokens, newPermissions.canTransferTokens);
        assertEq(updatePermissions.canTransferNative, newPermissions.canTransferNative);
        assertEq(updatePermissions.canSetMetadataURI, newPermissions.canSetMetadataURI);
    }

    function testCannot_updateAccountManagerPermissions_IfNotOwner(address someManager, address notOwner) public {
        vm.assume(notOwner != owner);
        vm.assume(notOwner != someManager);

        _setManagerWithoutFundManagementPermission(someManager);

        AccountManagerPermissions memory updatePermissions = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: true,
            canTransferNative: true,
            canSetMetadataURI: true
        });

        vm.prank(notOwner);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        account.updateAccountManagerPermissions(someManager, updatePermissions);
    }

    function testCannot_updateAccountManagerPermissions_IfManagerHasFullPermissions(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);

        _setManagerWithoutFundManagementPermission(someManager);
        AccountManagerPermissions memory updatePermissions = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: true,
            canTransferNative: true,
            canSetMetadataURI: true
        });

        vm.prank(manager); // global manager with full permissions
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        account.updateAccountManagerPermissions(someManager, updatePermissions);
    }

    function testCannot_updateAccountManagerPermissions_ForNotManager(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidParameter.selector);
        account.updateAccountManagerPermissions(someManager, AccountManagerPermissions(true, true, true, true));
    }

    function testCannot_updateAccountManagerPermissions_IfSamePermition(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);
        _setManagerWithoutFundManagementPermission(someManager);

        AccountManagerPermissions memory samePermissions = AccountManagerPermissions({
            canExecuteTransactions: true,
            canTransferTokens: false,
            canTransferNative: false,
            canSetMetadataURI: false
        });

        vm.prank(owner);
        vm.expectRevert(Errors.RedundantStateChange.selector);
        account.updateAccountManagerPermissions(someManager, samePermissions);
    }

    function test_removeAccountManager_IfOwner() public {
        assertTrue(account.isAccountManager(manager)); // global manager
        vm.prank(owner);
        account.removeAccountManager(manager);
        assertFalse(account.isAccountManager(manager));
    }

    function test_removeAccountManager_SelfRemove(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);
        _setManagerWithoutFundManagementPermission(someManager);
        assertTrue(account.isAccountManager(someManager));

        vm.prank(someManager);
        account.removeAccountManager(someManager);
        assertFalse(account.isAccountManager(someManager));
    }

    function testCannot_removeAccountManager_Twice() public {
        vm.prank(owner);
        account.removeAccountManager(manager);
        assertFalse(account.isAccountManager(manager));

        vm.prank(owner);
        vm.expectRevert(Errors.RedundantStateChange.selector);
        account.removeAccountManager(manager);
    }

    function testCannot_removeAccountManager_IfAddressIsNotManager(address notManager) public {
        _assumeCanBeAddedAsManager(notManager);
        assertFalse(account.isAccountManager(notManager));

        vm.prank(owner);
        vm.expectRevert(Errors.RedundantStateChange.selector);
        account.removeAccountManager(notManager);
    }

    function testCannot_removeAccountManager_IfManagerRemovesAnotherManager(address someManager) public {
        _assumeCanBeAddedAsManager(someManager);
        _setManagerWithoutFundManagementPermission(someManager);
        assertTrue(account.isAccountManager(someManager));

        vm.prank(manager); // global manager
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        account.removeAccountManager(someManager);
    }

    function test_supportsInterface() public view {
        assertTrue(account.supportsInterface(type(IERC1155Receiver).interfaceId));
        assertFalse(account.supportsInterface(0xdeadbeef));
    }
}

contract AccountTestHarness is FuzzZkTest, BaseDeployments {
    IHarnessAccount account;

    bytes32 constant PARAM__GRAPH = 0x7d50408405f482949cd317ab452b66f1104c85a1708ae5be893385b1c898c6d9;

    function setUp() public override {
        super.setUp();
        account = IHarnessAccount(payable(address(new HarnessAccount(address(GHO), address(WGHO)))));
    }

    function test_extractGraphFromParams(address addressToExtract) public view {
        KeyValue memory kv1 = KeyValue({key: keccak256("key1"), value: abi.encode("value1")});
        KeyValue memory kv2 = KeyValue({key: PARAM__GRAPH, value: abi.encode(addressToExtract)});
        KeyValue memory kv3 = KeyValue({key: keccak256("key3"), value: abi.encode("value3")});

        assertEq(account.extractGraphFromParams(_emptyKeyValueArray()), address(0));
        assertEq(account.extractGraphFromParams(_toKeyValueArray(kv1, kv3)), address(0));

        assertEq(account.extractGraphFromParams(_toKeyValueArray(kv2)), addressToExtract);
        assertEq(account.extractGraphFromParams(_toKeyValueArray(kv1, kv2, kv3)), addressToExtract);
    }
}

contract ErrorsTest {
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
