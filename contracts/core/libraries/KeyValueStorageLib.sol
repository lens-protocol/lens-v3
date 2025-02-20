// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";

library KeyValueStorageLib {
    function set(mapping(bytes32 => bytes) storage _keyValueStorage, KeyValue memory keyValueToSet)
        internal
        returns (bool)
    {
        return _setKeyValueToStorage(_keyValueStorage, keyValueToSet);
    }

    function set(mapping(bytes32 => bytes) storage _keyValueStorage, KeyValue[] calldata keyValuesToSet)
        internal
        returns (bool[] memory)
    {
        bool[] memory werePreviousValuesSet = new bool[](keyValuesToSet.length);
        for (uint256 i = 0; i < keyValuesToSet.length; i++) {
            werePreviousValuesSet[i] = _setKeyValueToStorage(_keyValueStorage, keyValuesToSet[i]);
        }
        return werePreviousValuesSet;
    }

    function _setKeyValueToStorage(mapping(bytes32 => bytes) storage _keyValueStorage, KeyValue memory keyValueToSet)
        internal
        returns (bool)
    {
        bool wasPreviousValueSet = _keyValueStorage[keyValueToSet.key].length != 0;
        _keyValueStorage[keyValueToSet.key] = keyValueToSet.value;
        return wasPreviousValueSet;
    }
}
