// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KeyValue, SourceStamp} from "./../types/Types.sol";
import {ExtraStorageBased} from "./ExtraStorageBased.sol";
import {ISource} from "./../interfaces/ISource.sol";

abstract contract SourceStampBased is ExtraStorageBased {
    bytes32 constant SOURCE_STAMP_CUSTOM_PARAM = keccak256("lens.core.sourceStamp");
    bytes32 constant SOURCE_EXTRA_DATA = keccak256("lens.core.source");
    bytes32 constant LAST_UPDATED_SOURCE_EXTRA_DATA = keccak256("lens.core.lastUpdatedSource");

    // TODO: We might consider moving source storing out of this contract (see Post created VS lastUpdated source)
    function _processSourceStamp(
        uint256 entityId,
        KeyValue[] calldata customParams,
        bool storeSource,
        bool lastUpdatedSourceType
    ) internal returns (address) {
        bytes32 key = lastUpdatedSourceType ? LAST_UPDATED_SOURCE_EXTRA_DATA : SOURCE_EXTRA_DATA;
        for (uint256 i = 0; i < customParams.length; i++) {
            if (customParams[i].key == SOURCE_STAMP_CUSTOM_PARAM) {
                if (customParams[i].value.length > 0) {
                    SourceStamp memory sourceStamp = abi.decode(customParams[i].value, (SourceStamp));
                    ISource(sourceStamp.source).validateSource(sourceStamp);
                    if (storeSource) {
                        _setPrimitiveInternalExtraDataForEntity(entityId, KeyValue(key, abi.encode(sourceStamp.source)));
                    }
                    return sourceStamp.source;
                } else {
                    if (storeSource) {
                        _setPrimitiveInternalExtraDataForEntity(entityId, KeyValue(key, ""));
                    }
                }
            }
        }
        return address(0);
    }

    function _processSourceStamp(
        uint256 entityId,
        KeyValue[] calldata customParams,
        bool storeSource
    ) internal returns (address) {
        return _processSourceStamp(entityId, customParams, storeSource, false);
    }

    function _processSourceStamp(uint256 entityId, KeyValue[] calldata customParams) internal returns (address) {
        return _processSourceStamp(entityId, customParams, true, false);
    }

    function _getSource(uint256 entityId) internal view returns (address) {
        bytes memory encodedSource = _getPrimitiveInternalExtraDataForEntity(entityId, SOURCE_EXTRA_DATA);
        if (encodedSource.length == 0) {
            return address(0);
        } else {
            return abi.decode(encodedSource, (address));
        }
    }

    function _getLastUpdateSource(uint256 entityId) internal view returns (address) {
        bytes memory encodedSource = _getPrimitiveInternalExtraDataForEntity(entityId, LAST_UPDATED_SOURCE_EXTRA_DATA);
        if (encodedSource.length == 0) {
            return address(0);
        } else {
            return abi.decode(encodedSource, (address));
        }
    }
}
