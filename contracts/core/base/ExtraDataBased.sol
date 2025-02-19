// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";
import {ExtraStorageBased} from "contracts/core/base/ExtraStorageBased.sol";

abstract contract ExtraDataBased is ExtraStorageBased {
    function _emitExtraDataAddedEvent(KeyValue calldata extraDataAdded) internal virtual;

    function _emitExtraDataUpdatedEvent(KeyValue calldata extraDataUpdated) internal virtual;

    function _emitExtraDataRemovedEvent(KeyValue calldata extraDataRemoved) internal virtual;

    function _setExtraData(KeyValue[] calldata extraDataToSet) internal {
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = _setExtraStorage_Self(extraDataToSet[i]);
            bool isNewValueEmpty = extraDataToSet[i].value.length == 0;
            if (hadAValueSetBefore) {
                if (isNewValueEmpty) {
                    _emitExtraDataRemovedEvent(extraDataToSet[i]);
                } else {
                    _emitExtraDataUpdatedEvent(extraDataToSet[i]);
                }
            } else if (!isNewValueEmpty) {
                _emitExtraDataAddedEvent(extraDataToSet[i]);
            }
        }
    }

    function _getExtraData(bytes32 key) internal view returns (bytes memory) {
        return _getExtraStorage_Self(key);
    }
}
