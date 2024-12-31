// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

library NamespaceCore {
    // Storage

    struct Storage {
        string namespace;
        mapping(string => bool) usernameExists; // TODO: Should this store the owner instead???
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

    // External functions - Use these functions to be called through DELEGATECALL

    function createUsername(string memory username) external {
        _createUsername(username);
    }

    function removeUsername(string memory username) external {
        _removeUsername(username);
    }

    function assignUsername(address account, string memory username) external {
        _assignUsername(account, username);
    }

    function unassignUsername(string memory username) external {
        _unassignUsername(username);
    }

    // Internal functions - Use these functions to be called as an inlined library

    function _createUsername(string memory username) internal {
        require(!$storage().usernameExists[username]); // Username must not exist yet
        require(bytes(username).length > 0); // Username must not be empty
        $storage().usernameExists[username] = true;
    }

    function _removeUsername(string memory username) internal {
        require($storage().usernameExists[username]); // Username must exist
        require($storage().usernameToAccount[username] == address(0)); // Username must not be assigned
        $storage().usernameExists[username] = false;
    }

    function _assignUsername(address account, string memory username) internal {
        require($storage().usernameExists[username]); // Username must exist
        require($storage().usernameToAccount[username] == address(0)); // Username must not be assigned yet
        require(bytes($storage().accountToUsername[account]).length == 0); // Account must not have a username yet
        $storage().usernameToAccount[username] = account;
        $storage().accountToUsername[account] = username;
    }

    function _unassignUsername(string memory username) internal {
        address account = $storage().usernameToAccount[username];
        require(account != address(0)); // Username must be assigned
        delete $storage().accountToUsername[account];
        delete $storage().usernameToAccount[username];
    }
}
