// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IMetadataBased} from "./../interfaces/IMetadataBased.sol";

abstract contract MetadataBased is IMetadataBased {
    struct MetadataURIStorage {
        string metadataURI;
    }

    // keccak256("lens.core.storage.metadataURI");
    bytes32 constant METADATA_URI_STORAGE_SLOT = 0x7cfa581476b2ba093d7009352a9703870dfb7840654f694519d74830044726e9;

    function $metadataStorage() internal pure returns (MetadataURIStorage storage _storage) {
        assembly {
            _storage.slot := METADATA_URI_STORAGE_SLOT
        }
    }

    function setMetadataURI(string memory metadataURI) external override {
        _beforeMetadataURIUpdate(metadataURI);
        _setMetadataURI(metadataURI);
    }

    function _setMetadataURI(string memory metadataURI) internal {
        $metadataStorage().metadataURI = metadataURI;
        _emitMetadataURISet(metadataURI);
    }

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal virtual {
        revert();
    }

    function _emitMetadataURISet(string memory /* metadataURI */ ) internal virtual;

    function getMetadataURI() external view override returns (string memory) {
        return $metadataStorage().metadataURI;
    }
}
