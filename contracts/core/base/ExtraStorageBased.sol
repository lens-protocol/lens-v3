// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";
import {KeyValueStorageLib} from "contracts/core/libraries/KeyValueStorageLib.sol";

abstract contract ExtraStorageBased {
    using KeyValueStorageLib for mapping(bytes32 => bytes);

    event Lens_ExtraStorageSet(address indexed addressScope, uint256 indexed entityId, bytes32 indexed key, bytes value);

    /**
     * ExtraStorage has the following keys:
     *  `address` an address, `uint256` an entity ID, and a `bytes32` custom storage key
     * Which map to a `bytes` value which contains any ABI-encoded data.
     *    address addr => uint256 entityId => bytes32 key => bytes value
     *
     * The key used in the address can be:
     *
     * address(0)           => Basic contract storage extension, set by its contract code itself / business logic
     *                         Functions: _setExtraStorage & _getExtraStorage
     *                                    _setEntityExtraStorage & _getEntityExtraStorage
     *
     * address(this)        => About the contract but set by its owner, admin, manager, or similar.
     *                         Functions: _setExtraStorage_Self & _getExtraStorage_Self
     *                                    _setEntityExtraStorage_Self & _getEntityExtraStorage_Self
     *
     *
     * any other address    => Set on the contract linked to that address.
     *                          Functions: _setEntityExtraStorage_Account & _getEntityExtraStorage_Account
     *
     *
     * The ExtraStorage access and ownership is meant to be controlled by the above cases on case-by-case basis.
     * Each implementation can choose how they allow & restrict write-access to it.
     *
     * EntityId is the ID of the entity (postId, followId, username hash, rule configSalt, etc)
     * EntityId == 0 is passed if the extraStorage is not entity-specific but rather general.
     *
     * Key is the keccak256 hash of the key (string) that is used to store the value, for example:
     *      keccak256("lens.data.myAppName.someCustomKey")
     */
    struct ExtraStorage {
        mapping(
            address addressScope
                => mapping(uint256 entityType => mapping(uint256 entityId => mapping(bytes32 key => bytes value)))
        ) slot;
    }

    /// @custom:keccak lens.storage.ExtraStorage
    bytes32 constant STORAGE__EXTRA_STORAGE = 0xfae2ddb96afe37e426489b23daa1bb7071e3786e8320e123d30b7ec1bc85340f;

    function $extraStorage() private pure returns (ExtraStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__EXTRA_STORAGE
        }
    }

    // Internal functions to set and get extra data

    function _storeExtraStorage(address addressScope, uint256 entityId, KeyValue memory extraStorageToSet)
        private
        returns (bool)
    {
        // In this release we always set the entityID to zero
        bool wasPreviousValueSet = $extraStorage().slot[addressScope][0][entityId].set(extraStorageToSet);
        emit Lens_ExtraStorageSet(addressScope, entityId, extraStorageToSet.key, extraStorageToSet.value);
        return wasPreviousValueSet;
    }

    function _loadExtraStorage(address addressScope, uint256 entityId, bytes32 key)
        private
        view
        returns (bytes memory)
    {
        // In this release we always set the entityID to zero
        return $extraStorage().slot[addressScope][0][entityId][key];
    }

    // Setter function for each different type of extra data

    function _setExtraStorage(KeyValue memory extraStorageToSet) internal returns (bool) {
        return _storeExtraStorage(address(0), 0, extraStorageToSet);
    }

    function _setEntityExtraStorage(uint256 entityId, KeyValue memory extraStorageToSet) internal returns (bool) {
        return _storeExtraStorage(address(0), entityId, extraStorageToSet);
    }

    function _setExtraStorage_Self(KeyValue memory extraStorageToSet) internal returns (bool) {
        return _storeExtraStorage(address(this), 0, extraStorageToSet);
    }

    function _setEntityExtraStorage_Self(uint256 entityId, KeyValue memory extraStorageToSet) internal returns (bool) {
        return _storeExtraStorage(address(this), entityId, extraStorageToSet);
    }

    function _setEntityExtraStorage_Account(uint256 entityId, KeyValue memory extraStorageToSet)
        internal
        returns (bool)
    {
        return _storeExtraStorage(msg.sender, entityId, extraStorageToSet);
    }

    // Getter function for each different type of extra data

    function _getExtraStorage(bytes32 key) internal view returns (bytes memory) {
        return _loadExtraStorage(address(0), 0, key);
    }

    function _getEntityExtraStorage(uint256 entityId, bytes32 key) internal view returns (bytes memory) {
        return _loadExtraStorage(address(0), entityId, key);
    }

    function _getExtraStorage_Self(bytes32 key) internal view returns (bytes memory) {
        return _loadExtraStorage(address(this), 0, key);
    }

    function _getEntityExtraStorage_Self(uint256 entityId, bytes32 key) internal view returns (bytes memory) {
        return _loadExtraStorage(address(this), entityId, key);
    }

    function _getEntityExtraStorage_Account(address addressScope, uint256 entityId, bytes32 key)
        internal
        view
        returns (bytes memory)
    {
        return _loadExtraStorage(addressScope, entityId, key);
    }
}
