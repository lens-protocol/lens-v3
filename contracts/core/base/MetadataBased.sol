// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

abstract contract MetadataBased {
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

    event Lens_MetadataURISet(string metadataURI);

    constructor(string memory metadataURI) {
        _setMetadataURI(metadataURI);
    }

    function setMetadataURI(string memory metadataURI) external {
        _beforeMetadataURIUpdate(metadataURI);
        _setMetadataURI(metadataURI);
    }

    function _setMetadataURI(string memory metadataURI) internal {
        $metadataStorage().metadataURI = metadataURI;
        emit Lens_MetadataURISet(metadataURI);
    }

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal virtual {
        revert();
    }

    function getMetadataURI() external view returns (string memory) {
        return $metadataStorage().metadataURI;
    }
}
