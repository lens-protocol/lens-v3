// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataElement} from "../../types/Types.sol";
import {ExtraDataLib} from "../libraries/ExtraDataLib.sol";

contract ExtraData {
    using ExtraDataLib for mapping(bytes32 => bytes);

    event Lens_ExtraDataSet(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_EmbeddedExtraDataSet(
        uint256 indexed embeddedId, bytes32 indexed key, bytes value, bytes indexed valueIndexed
    );

    // TODO: We can use (ID+key) concat to have extraData in embedded elements (like in FollowRules storage).
    // For example: Might worth to add extraData to the follow entity
    // Maybe it requires a targetExtraData and a followerExtraData
    // so then you have different auth for them, and they store different data
    // e.g. the follower can store a label/tag/category, like "I follow this account because of crypto/politics/etc"
    // and the target can store other information like tiers, etc.
    struct ExtraDataStorage {
        mapping(bytes32 => bytes) extraData;
    }

    // keccak256('lens.extra.data.storage') // TODO: Replace this with extraData or extra-data or smth
    // TODO: Why again we don't use dynamic keccak here?
    bytes32 constant EXTRA_DATA_STORAGE_SLOT = 0x5621042c955ed094415b555496ef3b1c763141305f49d509c25d873ce56b9465;

    function $extraDataStorage() private pure returns (ExtraDataStorage storage _storage) {
        assembly {
            _storage.slot := EXTRA_DATA_STORAGE_SLOT
        }
    }

    // Don't forget to override and add AccessControl in your primitive
    function setExtraData(DataElement[] calldata extraDataToSet) external virtual {
        _setExtraData(extraDataToSet);
    }

    // TODO: This is an example usage, might be not needed
    function setUserExtraData(DataElement[] calldata extraDataToSet) external virtual {
        _setEmbeddedExtraData(uint256(uint160(msg.sender)), extraDataToSet);
    }

    function _setExtraData(DataElement[] calldata extraDataToSet) internal {
        $extraDataStorage().extraData.set(extraDataToSet);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            emit Lens_ExtraDataSet(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
        }
    }

    function _setEmbeddedExtraData(uint256 embeddedId, DataElement[] calldata extraDataToSet) internal {
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bytes32 key = keccak256(abi.encode(extraDataToSet[i].key, embeddedId));
            emit Lens_EmbeddedExtraDataSet(embeddedId, key, extraDataToSet[i].value, extraDataToSet[i].value);
        }
    }

    function getExtraData(bytes32 key) external view returns (bytes memory) {
        return $extraDataStorage().extraData[key];
    }

    function getEmbeddedExtraData(uint256 embeddedId, bytes32 key) external view returns (bytes memory) {
        return $extraDataStorage().extraData[keccak256(abi.encode(key, embeddedId))];
    }
}
