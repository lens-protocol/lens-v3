// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/ExtraDataLib.sol";

library UsernameCore {
    using ExtraDataLib for mapping(bytes32 => bytes);

    // Storage

    struct Storage {
        string namespace;
        string metadataURI;
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

    function registerUsername(address account, string memory username) external {
        _registerUsername(account, username);
    }

    function unregisterUsername(string memory username) external {
        _unregisterUsername(username);
    }

    // Internal functions - Use these functions to be called as an inlined library

    function _registerUsername(address account, string memory username) internal {
        require(bytes(username).length > 0); // Username must not be empty
        require($storage().usernameToAccount[username] == address(0)); // Username must not be registered yet
        require(bytes($storage().accountToUsername[account]).length == 0); // Account must not have a username yet
        $storage().usernameToAccount[username] = account;
        $storage().accountToUsername[account] = username;
    }

    function _unregisterUsername(string memory username) internal {
        address account = $storage().usernameToAccount[username];
        require(account != address(0)); // Username must be registered
        delete $storage().accountToUsername[account];
        delete $storage().usernameToAccount[username];
    }

    function _setExtraData(DataElement[] calldata extraDataToSet) internal {
        $storage().extraData.set(extraDataToSet);
    }
}
