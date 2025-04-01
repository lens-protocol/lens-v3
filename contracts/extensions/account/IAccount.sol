// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {SourceStamp, KeyValue} from "contracts/core/types/Types.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IMetadataBased} from "contracts/core/interfaces/IMetadataBased.sol";

struct AccountManagerPermissions {
    bool canExecuteTransactions;
    bool canTransferTokens;
    bool canTransferNative;
    bool canSetMetadataURI;
}

struct Transaction {
    address target;
    uint256 value;
    bytes data;
}

interface IAccount is IMetadataBased, IERC1155Receiver, IERC721Receiver {
    event Lens_Account_MetadataURISet(string metadataURI);
    event Lens_Account_MetadataURISet(string metadataURI, address indexed source);
    event Lens_Account_OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Lens_Account_TransactionExecuted(address indexed target, uint256 value, bytes data, address indexed executor);
    event Lens_Account_AccountManagerAdded(address accountManager, AccountManagerPermissions permissions);
    event Lens_Account_AccountManagerRemoved(address accountManager);
    event Lens_Account_AccountManagerUpdated(address accountManager, AccountManagerPermissions permissions);
    event Lens_Account_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Account_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Account_ExtraDataRemoved(bytes32 indexed key);

    function addAccountManager(address _accountManager, AccountManagerPermissions calldata accountManagerPermissions)
        external;

    function removeAccountManager(address _accountManager) external;

    function updateAccountManagerPermissions(
        address accountManager,
        AccountManagerPermissions calldata accountManagerPermissions
    ) external;

    function setMetadataURI(string calldata _metadataURI, SourceStamp calldata sourceStamp) external;

    function setExtraData(KeyValue[] calldata extraDataToSet) external;

    function executeTransaction(address target, uint256 value, bytes calldata data)
        external
        payable
        returns (bytes memory);

    function executeTransactions(Transaction[] calldata transactions) external payable returns (bytes[] memory);

    function isAccountManager(address accountManager) external view returns (bool);

    function canExecuteTransactions(address executor) external view returns (bool);

    function canSetMetadataURI(address accountManager) external view returns (bool);

    function getAccountManagerPermissions(address accountManager)
        external
        view
        returns (AccountManagerPermissions memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);

    receive() external payable;
}
