// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";

library NamespaceCore {
    // Storage

    struct Storage {
        string namespace;
        mapping(string => bool) usernameExists;
        mapping(string => address) usernameToAccount;
        mapping(address => string) accountToUsername;
    }

    /// @custom:keccak lens.storage.NamespaceCore
    bytes32 constant STORAGE__NAMESPACE_CORE = 0x6d374ece44bcfef1b791ff4a0e88360ee8ce91bd6dc8916c39867f03ba1bfb84;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__NAMESPACE_CORE
        }
    }

    // Internal functions

    function _createUsername(string memory username) internal {
        require(!$storage().usernameExists[username], Errors.AlreadyExists()); // Username must not exist yet
        require(bytes(username).length > 0, Errors.InvalidParameter()); // Username must not be empty
        require(bytes(username).length < type(uint8).max, Errors.InvalidParameter()); // Length must be less than 255
        $storage().usernameExists[username] = true;
    }

    function _removeUsername(string memory username) internal {
        require($storage().usernameExists[username], Errors.DoesNotExist()); // Username must exist
        require($storage().usernameToAccount[username] == address(0), Errors.UsernameAssigned()); // Username must not be assigned
        $storage().usernameExists[username] = false;
    }

    function _assignUsername(address account, string memory username) internal {
        require($storage().usernameExists[username], Errors.DoesNotExist()); // Username must exist
        require($storage().usernameToAccount[username] == address(0), Errors.UsernameAssigned()); // Username must not be assigned yet
        require(bytes($storage().accountToUsername[account]).length == 0, Errors.UsernameAssigned()); // Account must not have a username yet
        $storage().usernameToAccount[username] = account;
        $storage().accountToUsername[account] = username;
    }

    function _unassignUsername(string memory username) internal {
        address account = $storage().usernameToAccount[username];
        require(account != address(0), Errors.RedundantStateChange()); // Username must be assigned
        delete $storage().accountToUsername[account];
        delete $storage().usernameToAccount[username];
    }
}
