// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {SourceStamp} from "./../../core/types/Types.sol";

struct AccountManagerPermissions {
    bool canExecuteTransactions;
    bool canTransferTokens;
    bool canTransferNative;
    bool canSetMetadataURI;
}

interface IAccount {
    event Lens_Account_MetadataURISet(string metadataURI, address indexed source);
    event Lens_Account_OwnerTransferred(address indexed newOwner);
    event Lens_Account_TransactionExecuted(address indexed to, uint256 value, bytes data, address indexed executor);
    event Lens_Account_AccountManagerAdded(address accountManager, AccountManagerPermissions permissions);
    event Lens_Account_AccountManagerRemoved(address accountManager);
    event Lens_Account_AccountManagerUpdated(address accountManager, AccountManagerPermissions permissions);
    event Lens_Account_AllowNonOwnerSpending(bool allow, uint256 timestamp);

    function addAccountManager(
        address _accountManager,
        AccountManagerPermissions calldata accountManagerPermissions
    ) external;

    function removeAccountManager(address _accountManager) external;

    function updateAccountManagerPermissions(
        address accountManager,
        AccountManagerPermissions calldata accountManagerPermissions
    ) external;

    function setMetadataURI(string calldata _metadataURI, SourceStamp calldata sourceStamp) external;

    function executeTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory);

    function getMetadataURI(address source) external view returns (string memory);

    function getAccountManagerPermissions(address accountManager)
        external
        view
        returns (AccountManagerPermissions memory);

    function canExecuteTransactions(address executor) external view returns (bool);

    receive() external payable;
}
