// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";
import {ExtraStorageBased} from "contracts/core/base/ExtraStorageBased.sol";

abstract contract EntityExtraDataBased is ExtraStorageBased {
    function _emitEntityExtraDataAddedEvent(uint256 entityId, KeyValue memory extraDataAdded) internal virtual;

    function _emitEntityExtraDataUpdatedEvent(uint256 entityId, KeyValue memory extraDataUpdated) internal virtual;

    function _emitEntityExtraDataRemovedEvent(uint256 entityId, KeyValue memory extraDataRemoved) internal virtual;

    function _setEntityExtraData(uint256 entityId, KeyValue[] memory extraDataToSet) internal virtual {
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = _setEntityExtraStorage_Account(entityId, extraDataToSet[i]);
            bool isNewValueEmpty = extraDataToSet[i].value.length == 0;
            if (hadAValueSetBefore) {
                if (isNewValueEmpty) {
                    _emitEntityExtraDataRemovedEvent(entityId, extraDataToSet[i]);
                } else {
                    _emitEntityExtraDataUpdatedEvent(entityId, extraDataToSet[i]);
                }
            } else if (!isNewValueEmpty) {
                _emitEntityExtraDataAddedEvent(entityId, extraDataToSet[i]);
            }
        }
    }

    function _getEntityExtraData(address addressScope, uint256 entityId, bytes32 key)
        internal
        view
        returns (bytes memory)
    {
        return _getEntityExtraStorage_Account(addressScope, entityId, key);
    }
}
