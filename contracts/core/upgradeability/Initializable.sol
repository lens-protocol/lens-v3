// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

abstract contract Initializable {
    // Storage

    struct Storage {
        bool initialized;
        bool initializing;
    }

    /// @custom:keccak lens.storage.Initializable
    bytes32 constant STORAGE__INITIALIZABLE = 0xbd2c04feebbff2d29fe1b04edf9a1d94ba7a836bad797bdd99c9e722e172cdd0;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__INITIALIZABLE
        }
    }

    modifier initializer() {
        require(!$storage().initialized, "ALREADY_INITIALIZED");
        $storage().initializing = true;
        _;
        $storage().initialized = true;
        $storage().initializing = false;
    }

    modifier onlyInitializing() {
        require($storage().initializing, "NOT_INITIALIZING");
        _;
    }

    function _disableInitializers() internal virtual {
        $storage().initialized = true;
    }
}
