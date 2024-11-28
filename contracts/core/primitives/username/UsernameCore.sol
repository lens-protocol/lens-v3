// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import "./../../libraries/ExtraDataLib.sol";

library UsernameCore {
    using ExtraDataLib for mapping(bytes32 => bytes);

    // Storage

    struct Storage {
        string namespace;
        string metadataURI;
        mapping(string => bool) usernameExists; // TODO: Should this store the owner instead???
        mapping(string => address) usernameToAccount;
        mapping(address => string) accountToUsername;
        mapping(bytes32 => bytes) extraData;
    }

    // keccak256('lens.username.core.storage')
    bytes32 constant CORE_STORAGE_SLOT = 0x99859b45773300f37fd6dda5224af64cfd118242932458b3472b7865bfa1b249;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := CORE_STORAGE_SLOT
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

    function setExtraData(KeyValue calldata extraDataToSet) external returns (bool) {
        return _setExtraData(extraDataToSet);
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

    function _setExtraData(KeyValue calldata extraDataToSet) internal returns (bool) {
        return $storage().extraData.set(extraDataToSet);
    }
}
