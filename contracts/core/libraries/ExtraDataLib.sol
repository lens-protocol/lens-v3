// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {KeyValue} from "./../types/Types.sol";

library ExtraDataLib {
    function set(
        mapping(bytes32 => bytes) storage _extraDataStorage,
        KeyValue memory extraKeyValueToSet
    ) internal returns (bool) {
        return _setExtraKeyValue(_extraDataStorage, extraKeyValueToSet);
    }

    function set(
        mapping(bytes32 => bytes) storage _extraDataStorage,
        KeyValue[] calldata extraDataToSet
    ) internal returns (bool[] memory) {
        bool[] memory werePreviousValuesSet = new bool[](extraDataToSet.length);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            werePreviousValuesSet[i] = _setExtraKeyValue(_extraDataStorage, extraDataToSet[i]);
        }
        return werePreviousValuesSet;
    }

    function _setExtraKeyValue(
        mapping(bytes32 => bytes) storage _extraDataStorage,
        KeyValue memory extraKeyValueToSet
    ) internal returns (bool) {
        bool wasPreviousValueSet = _extraDataStorage[extraKeyValueToSet.key].length != 0;
        _extraDataStorage[extraKeyValueToSet.key] = extraKeyValueToSet.value;
        return wasPreviousValueSet;
    }
}
