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

    function _processSourceStamp(bytes32 key, uint256 entityType, uint256 entityId, KeyValue[] memory customParams)
        internal
        returns (address)
    {
        address source = _processSourceStamp(customParams);
        if (source != address(0)) {
            _storeSource(key, entityType, entityId, source);
        } else {
            _clearSource(key, entityType, entityId);
        }
        return source;
    }

    function _processSourceStamp(KeyValue[] memory customParams) internal returns (address) {
        for (uint256 i = 0; i < customParams.length; i++) {
            if (customParams[i].key == PARAM__SOURCE_STAMP) {
                SourceStamp memory sourceStamp = abi.decode(customParams[i].value, (SourceStamp));
                require(sourceStamp.originalMsgSender == msg.sender);
                ISource(sourceStamp.source).validateSource(sourceStamp);
                return sourceStamp.source;
            }
        }
        return address(0);
    }

    function _storeSource(bytes32 key, uint256 entityType, uint256 entityId, address source) internal {
        _setEntityExtraStorage(entityType, entityId, KeyValue(key, abi.encode(source)));
    }

    function _clearSource(bytes32 key, uint256 entityType, uint256 entityId) internal {
        _setEntityExtraStorage(entityType, entityId, KeyValue(key, ""));
    }

    function _getSource(bytes32 key, uint256 entityType, uint256 entityId) internal view returns (address) {
        bytes memory encodedSource = _getEntityExtraStorage(entityType, entityId, key);
        if (encodedSource.length == 0) {
            return address(0);
        } else {
            return abi.decode(encodedSource, (address));
        }
    }

    // Functions with default 0 entityType hardcoded

    function _processSourceStamp(bytes32 key, uint256 entityId, KeyValue[] memory customParams)
        internal
        returns (address)
    {
        return _processSourceStamp(key, 0, entityId, customParams);
    }

    function _storeSource(bytes32 key, uint256 entityId, address source) internal {
        _storeSource(key, 0, entityId, source);
    }

    function _clearSource(bytes32 key, uint256 entityId) internal {
        _clearSource(key, 0, entityId);
    }

    function _getSource(bytes32 key, uint256 entityId) internal view returns (address) {
        return _getSource(key, 0, entityId);
    }

    // Functions with default `lens.data.source` key hardcoded

    function _processSourceStamp(uint256 entityType, uint256 entityId, KeyValue[] memory customParams)
        internal
        returns (address)
    {
        return _processSourceStamp(DATA__SOURCE, entityType, entityId, customParams);
    }

    function _storeSource(uint256 entityType, uint256 entityId, address source) internal {
        _storeSource(DATA__SOURCE, entityType, entityId, source);
    }

    function _clearSource(uint256 entityType, uint256 entityId) internal {
        _clearSource(DATA__SOURCE, entityType, entityId);
    }

    function _getSource(uint256 entityType, uint256 entityId) internal view returns (address) {
        return _getSource(DATA__SOURCE, entityType, entityId);
    }

    // Functions with default `lens.data.source` key and default 0 entityType hardcoded

    function _processSourceStamp(uint256 entityId, KeyValue[] memory customParams) internal returns (address) {
        return _processSourceStamp(DATA__SOURCE, 0, entityId, customParams);
    }

    function _storeSource(uint256 entityId, address source) internal {
        _storeSource(DATA__SOURCE, 0, entityId, source);
    }

    function _clearSource(uint256 entityId) internal {
        _clearSource(DATA__SOURCE, 0, entityId);
    }

    function _getSource(uint256 entityId) internal view returns (address) {
        return _getSource(DATA__SOURCE, 0, entityId);
    }
}
