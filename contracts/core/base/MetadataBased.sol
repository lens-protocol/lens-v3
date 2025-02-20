// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IMetadataBased} from "contracts/core/interfaces/IMetadataBased.sol";
import {Errors} from "contracts/core/types/Errors.sol";

abstract contract MetadataBased is IMetadataBased {
    // source = address(0)          =>  Global MetadataURI
    // source = any other address   =>  MetadataURI set by specific source
    struct MetadataURIStorage {
        mapping(address => string) metadataURI;
    }

    /// @custom:keccak lens.storage.metadataURI
    bytes32 constant STORAGE__METADATA_URI = 0x1e3609457e69da9dd0dabac13fb8ca9b651f93d6966199d652f92264e8b2ea10;

    function $metadataStorage() internal pure returns (MetadataURIStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__METADATA_URI
        }
    }

    function setMetadataURI(string memory metadataURI) external override {
        _beforeMetadataURIUpdate(metadataURI);
        // solc-ignore-next-line unreachable
        _setMetadataURI(metadataURI);
    }

    function _setMetadataURI(string memory metadataURI) internal {
        $metadataStorage().metadataURI[address(0)] = metadataURI;
        _emitMetadataURISet(metadataURI, address(0));
    }

    function _setMetadataURI(string memory metadataURI, address source) internal {
        $metadataStorage().metadataURI[source] = metadataURI;
        _emitMetadataURISet(metadataURI, source);
    }

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal virtual {
        revert Errors.NotImplemented();
    }

    function _emitMetadataURISet(string memory, /* metadataURI */ address /* source */ ) internal virtual;

    function getMetadataURI() external view override returns (string memory) {
        return $metadataStorage().metadataURI[address(0)];
    }

    function getMetadataURI(address source) external view returns (string memory) {
        return $metadataStorage().metadataURI[source];
    }
}
