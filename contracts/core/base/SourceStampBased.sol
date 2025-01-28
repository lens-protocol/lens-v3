// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {KeyValue, SourceStamp} from "contracts/core/types/Types.sol";
import {ExtraStorageBased} from "contracts/core/base/ExtraStorageBased.sol";
import {ISource} from "contracts/core/interfaces/ISource.sol";

abstract contract SourceStampBased is ExtraStorageBased {
    /// @custom:keccak lens.param.sourceStamp
    bytes32 constant PARAM__SOURCE_STAMP = 0xedc03eff258927169d8466a6d671afad7cb0b69c2ad73f480eab23a233329cfc;
    /// @custom:keccak lens.data.source
    bytes32 constant DATA__SOURCE = 0xe256f222b2a828c71663f947d88e5c36216c58578c760b915641bf46ffe6a66e;
    /// @custom:keccak lens.data.lastUpdatedSource
    bytes32 constant DATA__LAST_UPDATED_SOURCE = 0x3cd0f450c58e5572a9f19a4af172d526fb9645ba11a751c1e6fe7f53c4d956eb;

    // TODO: We might consider moving source storing out of this contract (see Post created VS lastUpdated source)
    function _processSourceStamp(
        uint256 entityId,
        KeyValue[] memory customParams,
        bool storeSource,
        bool lastUpdatedSourceType
    ) internal returns (address) {
        bytes32 key = lastUpdatedSourceType ? DATA__LAST_UPDATED_SOURCE : DATA__SOURCE;
        for (uint256 i = 0; i < customParams.length; i++) {
            if (customParams[i].key == PARAM__SOURCE_STAMP) {
                if (customParams[i].value.length > 0) {
                    SourceStamp memory sourceStamp = abi.decode(customParams[i].value, (SourceStamp));
                    require(sourceStamp.originalMsgSender == msg.sender);
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

    function _processSourceStamp(uint256 entityId, KeyValue[] memory customParams, bool storeSource)
        internal
        returns (address)
    {
        return _processSourceStamp(entityId, customParams, storeSource, false);
    }

    function _processSourceStamp(uint256 entityId, KeyValue[] memory customParams) internal returns (address) {
        return _processSourceStamp(entityId, customParams, true, false);
    }

    function _getSource(uint256 entityId) internal view returns (address) {
        bytes memory encodedSource = _getPrimitiveInternalExtraDataForEntity(entityId, DATA__SOURCE);
        if (encodedSource.length == 0) {
            return address(0);
        } else {
            return abi.decode(encodedSource, (address));
        }
    }

    function _getLastUpdateSource(uint256 entityId) internal view returns (address) {
        bytes memory encodedSource = _getPrimitiveInternalExtraDataForEntity(entityId, DATA__LAST_UPDATED_SOURCE);
        if (encodedSource.length == 0) {
            return address(0);
        } else {
            return abi.decode(encodedSource, (address));
        }
    }
}
