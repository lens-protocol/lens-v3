// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KeyValue} from "./../types/Types.sol";
import {ExtraDataLib} from "../libraries/ExtraDataLib.sol";

abstract contract ExtraStorageBased {
    using ExtraDataLib for mapping(bytes32 => bytes);

    // TODO: Consider supporting multi-entity primitives by adding "bytes32 entityType" in addition to existing keys
    event Lens_ExtraDataSet(address indexed addr, uint256 indexed entityId, bytes32 indexed key, bytes value);

    /*
     * ExtraStorage is organized like this:
     * address Address => uint256 EntityId => bytes32 Key => bytes ABIEncodedValue
     *
     * Where Address is either of:
     *  - address(0) for the PrimitiveSet extra storage (the primitive controls and generates it)
     *  - address(this) for the owner-controlled extra storage (for setting primitive metadata, primitive params, etc)
     *  - address(entity-owner) for the entity-owned extra storage (for setting entity metadata, params, etc)
     *  - address(rule) for the rule-controlled & rule-generated extra storage
     *  - address(any) for user-controlled extra storage (setting any metadata by the user (tags, bookmarks, etc))
     *
     * The ExtraStorage access and ownership is meant to be controlled by the above cases on case-by-case basis.
     * Each implementation can choose how they allow & restrict write-access to it.
     *
     * EntityId is the ID of the entity (postId, followId, username hash, rule configSalt, etc)
     * EntityId == 0 is passed if the extraData is not entity-specific but rather general for primitive/account/rule/etc
     *
     * Key is the keccak256 hash of the key (string) that is used to store the Value
     */
    struct ExtraDataStorage {
        mapping(address => mapping(uint256 => mapping(bytes32 => bytes))) extraStorage;
    }

    // keccak256('lens.extra.storage')
    // TODO: Why again we don't use dynamic keccak here?
    bytes32 constant EXTRA_STORAGE_SLOT = 0x46682673acfb524e27de924ad404eee31c5d1237de941d864bdf1364c405fb35;

    function $extraDataStorage() private pure returns (ExtraDataStorage storage _storage) {
        assembly {
            _storage.slot := EXTRA_STORAGE_SLOT
        }
    }

    function _setExtraData(address addr, uint256 entityId, KeyValue memory extraDataToSet) internal returns (bool) {
        bool wasPreviousValueSet = $extraDataStorage().extraStorage[addr][entityId].set(extraDataToSet);
        emit Lens_ExtraDataSet(addr, entityId, extraDataToSet.key, extraDataToSet.value);
        return wasPreviousValueSet;
    }

    function _getExtraData(address addr, uint256 entityId, bytes32 key) internal view returns (bytes memory) {
        return $extraDataStorage().extraStorage[addr][entityId][key];
    }

    // Helper functions to set different types of extra data

    function _setPrimitiveInternalExtraData(KeyValue memory extraDataToSet) internal returns (bool) {
        return _setExtraData(address(0), 0, extraDataToSet);
    }

    function _setPrimitiveInternalExtraDataForEntity(
        uint256 entityId,
        KeyValue memory extraDataToSet
    ) internal returns (bool) {
        return _setExtraData(address(0), entityId, extraDataToSet);
    }

    // TODO: rename to PrimitiveOwner?
    function _setPrimitiveExtraData(KeyValue memory extraDataToSet) internal returns (bool) {
        return _setExtraData(address(this), 0, extraDataToSet);
    }

    // TODO: rename to PrimitiveOwner?
    function _setPrimitiveExtraDataForEntity(uint256 entityId, KeyValue memory extraDataToSet) internal returns (bool) {
        return _setExtraData(address(this), entityId, extraDataToSet);
    }

    // TODO: Currently we don't have a entityBased extraData that doesn't change if the owner is changed. Should we?

    // TODO: rename to accent it's user/author-set?
    function _setEntityExtraData(uint256 entityId, KeyValue memory extraDataToSet) internal returns (bool) {
        return _setExtraData(msg.sender, entityId, extraDataToSet);
    }

    function _getPrimitiveInternalExtraData(bytes32 key) internal view returns (bytes memory) {
        return _getExtraData(address(0), 0, key);
    }

    function _getPrimitiveInternalExtraDataForEntity(
        uint256 entityId,
        bytes32 key
    ) internal view returns (bytes memory) {
        return _getExtraData(address(0), entityId, key);
    }

    function _getPrimitiveExtraData(bytes32 key) internal view returns (bytes memory) {
        return _getExtraData(address(this), 0, key);
    }

    function _getPrimitiveExtraDataForEntity(uint256 entityId, bytes32 key) internal view returns (bytes memory) {
        return _getExtraData(address(this), entityId, key);
    }

    function _getEntityExtraData(address addr, uint256 entityId, bytes32 key) internal view returns (bytes memory) {
        return _getExtraData(addr, entityId, key);
    }
}
