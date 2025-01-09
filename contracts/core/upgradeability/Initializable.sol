// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

abstract contract Initializable {
    // Storage

    struct InitializableStorage {
        bool initialized;
    }

    /// @custom:keccak lens.storage.Initializable
    bytes32 constant STORAGE__INITIALIZABLE = 0xbd2c04feebbff2d29fe1b04edf9a1d94ba7a836bad797bdd99c9e722e172cdd0;

    function $initializableStorage() internal pure returns (InitializableStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__INITIALIZABLE
        }
    }

    modifier initializer() {
        require(!$initializableStorage().initialized, "ALREADY_INITIALIZED");
        $initializableStorage().initialized = true;
        _;
    }

    function _disableInitializers() internal virtual {
        $initializableStorage().initialized = true;
    }
}
