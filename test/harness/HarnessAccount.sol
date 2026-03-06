// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {Account} from "contracts/extensions/account/Account.sol";
import {IAccount} from "contracts/extensions/account/IAccount.sol";
import {KeyValue} from "contracts/core/types/Types.sol";

interface IHarnessAccount is IAccount {
    function extractGraphFromParams(KeyValue[] calldata params) external pure returns (address);
}

contract HarnessAccount is IHarnessAccount, Account {
    constructor(address nativeGHO, address wrappedGHO) Account(nativeGHO, wrappedGHO) {}

    function extractGraphFromParams(KeyValue[] calldata params) external pure returns (address) {
        return _extractGraphFromParams(params);
    }
}
