// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Account} from "contracts/extensions/account/Account.sol";
import {AccountManagerPermissions, Transaction} from "contracts/extensions/account/IAccount.sol";
import {SourceStamp, KeyValue} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {ISource} from "contracts/core/interfaces/ISource.sol";
import {WHITELISTED_MULTICALL_ADDRESS} from "contracts/migration/WhitelistedMulticall.sol";

contract MigrationAccount is Account {
    modifier onlyWhitelistedMulticall() {
        require(msg.sender == WHITELISTED_MULTICALL_ADDRESS, Errors.InvalidMsgSender());
        _;
    }

    function setMetadataURI(string calldata metadataURI, SourceStamp calldata sourceStamp)
        external
        override
        onlyWhitelistedMulticall
    {
        // !!! MIGRATION ONLY
        // if (msg.sender != owner()) {
        //     require($storage().accountManagerPermissions[msg.sender].canSetMetadataURI, Errors.NotAllowed());
        // }
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
            _setMetadataURI(metadataURI, sourceStamp.source);
        } else {
            _setMetadataURI(metadataURI);
        }
    }

    function addAccountManager(address accountManager, AccountManagerPermissions calldata accountManagerPermissions)
        external
        override
        onlyWhitelistedMulticall
    {
        require(
            !$storage().accountManagerPermissions[accountManager].canExecuteTransactions, Errors.RedundantStateChange()
        );
        require(accountManager != owner(), Errors.InvalidParameter());
        require(accountManager != address(0), Errors.InvalidParameter());
        $storage().accountManagerPermissions[accountManager] = accountManagerPermissions;
        emit Lens_Account_AccountManagerAdded(accountManager, accountManagerPermissions);
    }

    function removeAccountManager(address accountManager) external override onlyWhitelistedMulticall {
        require(
            $storage().accountManagerPermissions[accountManager].canExecuteTransactions, Errors.RedundantStateChange()
        );
        delete $storage().accountManagerPermissions[accountManager];
        emit Lens_Account_AccountManagerRemoved(accountManager);
    }

    function updateAccountManagerPermissions(
        address accountManager,
        AccountManagerPermissions calldata accountManagerPermissions
    ) external override onlyWhitelistedMulticall {
        require($storage().accountManagerPermissions[accountManager].canExecuteTransactions, Errors.InvalidParameter());
        require(accountManagerPermissions.canExecuteTransactions, Errors.InvalidParameter());
        $storage().accountManagerPermissions[accountManager] = accountManagerPermissions;
        emit Lens_Account_AccountManagerUpdated(accountManager, accountManagerPermissions);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override onlyWhitelistedMulticall {
        _decodeAndSetExtraData(extraDataToSet);
    }

    function executeTransactions(Transaction[] calldata transactions)
        external
        payable
        override
        onlyWhitelistedMulticall
        returns (bytes[] memory)
    {
        // !!! MIGRATION ONLY
        // require(
        //     msg.sender == owner() || $storage().accountManagerPermissions[msg.sender].canExecuteTransactions,
        //     Errors.NotAllowed()
        // );
        bytes[] memory returnData = new bytes[](transactions.length);
        for (uint256 i = 0; i < transactions.length; i++) {
            returnData[i] = _executeTransaction(transactions[i].target, transactions[i].value, transactions[i].data);
        }
        return returnData;
    }

    function transferOwnership(address newOwner) public virtual override onlyWhitelistedMulticall {
        // !!! MIGRATION ONLY
        _transferOwnership(newOwner);
    }
}
