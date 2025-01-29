// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";
import {ExtraDataLib} from "contracts/core/libraries/ExtraDataLib.sol";

abstract contract ExtraStorageBased {
    using ExtraDataLib for mapping(bytes32 => bytes);

    event Lens_ExtraDataSet(address indexed addr, uint256 indexed entityId, bytes32 indexed key, bytes value);

    /**
     * ExtraStorage has the following keys:
     *  `address` an address, `uint256` an entity ID, and a `bytes32` custom storage key
     * Which map to a `bytes` value which contains any ABI-encoded data.
     *    address addr => uint256 entityId => bytes32 key => bytes value
     *
     * The key used in the address can be:
     * address(0) => Basic primitive storage extension, set by primitive code / business logic
     * address(this) => About the primitive but set by its owner
     * any other address => Set on the primitive linked to that address.
     *
     * The ExtraStorage access and ownership is meant to be controlled by the above cases on case-by-case basis.
     * Each implementation can choose how they allow & restrict write-access to it.
     *
     * EntityId is the ID of the entity (postId, followId, username hash, rule configSalt, etc)
     * EntityId == 0 is passed if the extraData is not entity-specific but rather general.
     *
     * Key is the keccak256 hash of the key (string) that is used to store the value, for example:
     *      keccak256("lens.data.myAppName.someCustomKey")
     */
    struct ExtraDataStorage {
        mapping(
            address addressScope
                => mapping(uint256 entityType => mapping(uint256 entityId => mapping(bytes32 key => bytes value)))
        ) extraStorage;
    }

    /// @custom:keccak lens.storage.ExtraDataStorage
    bytes32 constant STORAGE__EXTRA_STORAGE = 0xfcea8b4575b2819c79ea87472ec531dc6bcf2b1f70176b2f7050dc0569bb7a44;

    function $extraDataStorage() private pure returns (ExtraDataStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__EXTRA_STORAGE
        }
    }

    // Internal functions to set and get extra data

    function _private_setExtraData(address addr, uint256 entityId, KeyValue memory extraDataToSet)
        private
        returns (bool)
    {
        // In this release we always set the entityID to zero
        bool wasPreviousValueSet = $extraDataStorage().extraStorage[addr][0][entityId].set(extraDataToSet);
        emit Lens_ExtraDataSet(addr, entityId, extraDataToSet.key, extraDataToSet.value);
        return wasPreviousValueSet;
    }

    function _private_getExtraData(address addr, uint256 entityId, bytes32 key) private view returns (bytes memory) {
        // In this release we always set the entityID to zero
        return $extraDataStorage().extraStorage[addr][0][entityId][key];
    }

    // Setter function for each different type of extra data

    function _setExtraData(KeyValue memory extraDataToSet) internal returns (bool) {
        return _private_setExtraData(address(0), 0, extraDataToSet);
    }

    function _setEntityExtraData(uint256 entityId, KeyValue memory extraDataToSet) internal returns (bool) {
        return _private_setExtraData(address(0), entityId, extraDataToSet);
    }

    function _setExtraData_Primitive(KeyValue memory extraDataToSet) internal returns (bool) {
        return _private_setExtraData(address(this), 0, extraDataToSet);
    }

    function _setEntityExtraData_Primitive(uint256 entityId, KeyValue memory extraDataToSet) internal returns (bool) {
        return _private_setExtraData(address(this), entityId, extraDataToSet);
    }

    function _setEntityExtraData_Account(uint256 entityId, KeyValue memory extraDataToSet) internal returns (bool) {
        return _private_setExtraData(msg.sender, entityId, extraDataToSet);
    }

    // Getter function for each different type of extra data

    function _getExtraData(bytes32 key) internal view returns (bytes memory) {
        return _private_getExtraData(address(0), 0, key);
    }

    function _getEntityExtraData(uint256 entityId, bytes32 key) internal view returns (bytes memory) {
        return _private_getExtraData(address(0), entityId, key);
    }

    function _getExtraData_Primitive(bytes32 key) internal view returns (bytes memory) {
        return _private_getExtraData(address(this), 0, key);
    }

    function _getEntityExtraData_Primitive(uint256 entityId, bytes32 key) internal view returns (bytes memory) {
        return _private_getExtraData(address(this), entityId, key);
    }

    function _getEntityExtraData_Account(address addr, uint256 entityId, bytes32 key)
        internal
        view
        returns (bytes memory)
    {
        return _private_getExtraData(addr, entityId, key);
    }
}
