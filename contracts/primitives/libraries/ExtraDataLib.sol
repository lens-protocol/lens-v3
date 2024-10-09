// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DataElement} from "../../types/Types.sol";

library ExtraDataLib {
    function set(mapping(bytes32 => bytes) storage _extraDataStorage, DataElement[] calldata extraDataToSet) internal {
        _setExtraData(_extraDataStorage, extraDataToSet);
    }

    function _setExtraData(mapping(bytes32 => bytes) storage _extraDataStorage, DataElement[] calldata extraDataToSet)
        internal
    {
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            _extraDataStorage[extraDataToSet[i].key] = extraDataToSet[i].value;
        }
    }
}
