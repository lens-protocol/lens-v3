// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import {DataElement} from "./../types/Types.sol";

library ExtraDataLib {
    function set(
        mapping(bytes32 => bytes) storage _extraDataStorage,
        DataElement memory extraDataElementToSet
    ) internal returns (bool) {
        return _setExtraDataElement(_extraDataStorage, extraDataElementToSet);
    }

    function set(
        mapping(bytes32 => bytes) storage _extraDataStorage,
        DataElement[] calldata extraDataToSet
    ) internal returns (bool[] memory) {
        bool[] memory werePreviousValuesSet = new bool[](extraDataToSet.length);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            werePreviousValuesSet[i] = _setExtraDataElement(_extraDataStorage, extraDataToSet[i]);
        }
        return werePreviousValuesSet;
    }

    function _setExtraDataElement(
        mapping(bytes32 => bytes) storage _extraDataStorage,
        DataElement memory extraDataElementToSet
    ) internal returns (bool) {
        bool wasPreviousValueSet = _extraDataStorage[extraDataElementToSet.key].length != 0;
        _extraDataStorage[extraDataElementToSet.key] = extraDataElementToSet.value;
        return wasPreviousValueSet;
    }
}
