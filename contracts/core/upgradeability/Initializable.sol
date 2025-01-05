// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

abstract contract Initializable {
    // Storage

    struct Storage {
        bool initialized;
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
        $storage().initialized = true;
        _;
    }

    function _disableInitializers() internal virtual {
        $storage().initialized = true;
    }
}
