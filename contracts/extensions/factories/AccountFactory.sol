// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Account, AccountManagerPermissions} from "contracts/extensions/account/Account.sol";
import {KeyValue, SourceStamp} from "contracts/core/types/Types.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {ProxyAdmin} from "contracts/core/upgradeability/ProxyAdmin.sol";

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

    address internal immutable _beacon;
    address internal immutable _lock;

    constructor(address beacon, address lock) {
        _beacon = beacon;
        _lock = lock;
    }

    function deployAccount(
        address owner,
        string calldata metadataURI,
        address[] calldata accountManagers,
        AccountManagerPermissions[] calldata accountManagersPermissions,
        SourceStamp calldata sourceStamp,
        KeyValue[] calldata extraData
    ) external returns (address) {
        address proxyAdmin = address(new ProxyAdmin(owner, _lock)); // Owner of Proxy Admin same as owner of Account
        Account account = Account(payable(new BeaconProxy(proxyAdmin, _beacon)));
        account.initialize(owner, metadataURI, accountManagers, accountManagersPermissions, sourceStamp, extraData);
        emit Lens_Account_Created(
            address(account),
            owner,
            metadataURI,
            accountManagers,
            accountManagersPermissions,
            sourceStamp.source,
            extraData
        );
        return payable(account);
    }
}
