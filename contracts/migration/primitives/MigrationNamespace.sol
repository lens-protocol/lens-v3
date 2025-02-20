// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Namespace} from "contracts/core/primitives/namespace/Namespace.sol";
import {EventEmitter} from "contracts/migration/EventEmitter.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {KeyValueStorageLib} from "contracts/core/libraries/KeyValueStorageLib.sol";

contract MigrationNamespace is Namespace, EventEmitter {
    using KeyValueStorageLib for mapping(bytes32 => bytes);

    function $migrationExtraStorage() private pure returns (ExtraStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__EXTRA_STORAGE
        }
    }

    function _setEntityExtraData(uint256 tokenId, KeyValue[] memory extraDataToSet) internal override {
        address usernameOwner = ownerOf(tokenId);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            // Storing extra data in the native extra storage for data integrity
            _setEntityExtraStorage(tokenId, extraDataToSet[i]);
            // Forcing ExtraStorageBased::_setEntityExtraStorage_Account with injected addressScope
            _migration_force__setEntityExtraStorage_Account(usernameOwner, tokenId, extraDataToSet[i]);
            emit Lens_Username_ExtraDataAdded(
                tokenId, extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
            );
        }
    }

    function _migration_force__setEntityExtraStorage_Account(
        address addressScope,
        uint256 entityId,
        KeyValue memory extraDataToSet
    ) private {
        // In this release we always set the entityType to zero
        $migrationExtraStorage().slot[addressScope][0][entityId].set(extraDataToSet);
        emit Lens_ExtraStorageSet(addressScope, 0, entityId, extraDataToSet.key, extraDataToSet.value);
    }
}
