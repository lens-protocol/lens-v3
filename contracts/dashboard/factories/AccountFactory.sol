// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {Account, AccountManagerPermissions} from "./../account/Account.sol";
import {KeyValue, SourceStamp} from "./../../core/types/Types.sol";

contract AccountFactory {
    event Lens_Account_Created(
        address indexed account,
        address indexed owner,
        string metadataURI,
        address[] accountManagers,
        AccountManagerPermissions[] accountManagersPermissions,
        address indexed source,
        KeyValue[] extraData
    );

    function deployAccount(
        address owner,
        string calldata metadataURI,
        address[] calldata accountManagers,
        AccountManagerPermissions[] calldata accountManagersPermissions,
        SourceStamp calldata sourceStamp,
        KeyValue[] calldata extraData
    ) external returns (address) {
        // TODO: Make it a proxy
        Account account =
            new Account(owner, metadataURI, accountManagers, accountManagersPermissions, sourceStamp, extraData);
        emit Lens_Account_Created(
            address(account),
            owner,
            metadataURI,
            accountManagers,
            accountManagersPermissions,
            sourceStamp.source,
            extraData
        );
        return address(account);
    }
}
