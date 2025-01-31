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

    // Functions with generic key
    function _processSourceStamp(bytes32 key, uint256 entityId, KeyValue[] memory customParams, bool storeSource)
        internal
        returns (address)
    {
        for (uint256 i = 0; i < customParams.length; i++) {
            if (customParams[i].key == PARAM__SOURCE_STAMP) {
                if (customParams[i].value.length > 0) {
                    SourceStamp memory sourceStamp = abi.decode(customParams[i].value, (SourceStamp));
                    require(sourceStamp.originalMsgSender == msg.sender);
                    ISource(sourceStamp.source).validateSource(sourceStamp);
                    if (storeSource) {
                        _setEntityExtraStorage(entityId, KeyValue(key, abi.encode(sourceStamp.source)));
                    }
                    return sourceStamp.source;
                } else {
                    if (storeSource) {
                        _setEntityExtraStorage(entityId, KeyValue(key, ""));
                    }
                }
            }
        }
        return address(0);
    }

    function _getSource(bytes32 key, uint256 entityId) internal view returns (address) {
        bytes memory encodedSource = _getEntityExtraStorage(entityId, key);
        if (encodedSource.length == 0) {
            return address(0);
        } else {
            return abi.decode(encodedSource, (address));
        }
    }

    // Functions with hardcoded `lens.data.source` key

    function _processSourceStamp(uint256 entityId, KeyValue[] memory customParams, bool storeSource)
        internal
        returns (address)
    {
        return _processSourceStamp(DATA__SOURCE, entityId, customParams, storeSource);
    }

    function _processSourceStamp(uint256 entityId, KeyValue[] memory customParams) internal returns (address) {
        return _processSourceStamp(entityId, customParams, true);
    }

    function _getSource(uint256 entityId) internal view returns (address) {
        return _getSource(DATA__SOURCE, entityId);
    }
}
