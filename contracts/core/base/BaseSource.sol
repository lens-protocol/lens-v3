// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {ISource} from "./../interfaces/ISource.sol";
import {SourceStamp} from "./../types/Types.sol";

abstract contract BaseSource is ISource {
    bytes2 internal immutable EIP191_VERSION_BYTE_0X01_HEADER = 0x1901;
    string constant EIP712_DOMAIN_VERSION = "1";
    bytes32 constant EIP712_DOMAIN_VERSION_HASH = keccak256(bytes(EIP712_DOMAIN_VERSION));
    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant SOURCE_STAMP_TYPEHASH = keccak256("SourceStamp(address source,uint256 nonce,uint256 deadline)");

    mapping(uint256 => bool) internal _wasSourceStampNonceUsed;

    function validateSource(SourceStamp calldata sourceStamp) external virtual override {
        _validateSource(sourceStamp);
    }

    // Signature Standard: EIP-191 - Version Byte: 0x00
    function _validateSource(SourceStamp calldata sourceStamp) internal virtual {
        require(!_wasSourceStampNonceUsed[sourceStamp.nonce]);
        require(sourceStamp.deadline >= block.timestamp);
        require(sourceStamp.source == address(this));
        _wasSourceStampNonceUsed[sourceStamp.nonce] = true;
        bytes32 digest = _calculateDigest(_calculateHashStruct(sourceStamp));
        bytes32 r;
        bytes32 s;
        uint8 v;
        bytes memory signature = sourceStamp.signature;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        address signer = ecrecover(digest, v, r, s);
        require(_isValidSourceStampSigner(signer));
    }

    function _isValidSourceStampSigner(address signer) internal virtual returns (bool);

    function _calculateHashStruct(SourceStamp memory sourceStamp) private pure returns (bytes32) {
        return keccak256(abi.encode(SOURCE_STAMP_TYPEHASH, sourceStamp.source, sourceStamp.nonce, sourceStamp.deadline));
    }

    function _calculateDigest(bytes32 hashStruct) private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(EIP191_VERSION_BYTE_0X01_HEADER, _calculateDomainSeparatorHashStruct(), hashStruct)
        );
    }

    function _calculateDomainSeparatorHashStruct() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256("Lens Source"),
                EIP712_DOMAIN_VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }
}
