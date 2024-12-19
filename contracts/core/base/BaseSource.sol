// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {ISource} from "./../interfaces/ISource.sol";
import {SourceStamp} from "./../types/Types.sol";

abstract contract BaseSource is ISource {
    uint256 internal immutable EC_SIGNATURE_LENGTH = 65;
    bytes2 internal immutable EIP191_VERSION_BYTE_0X00_HEADER = 0x1900;

    mapping(uint256 => bool) internal _wasSourceStampNonceUsed;

    function validateSource(
        SourceStamp calldata sourceStamp
    ) external virtual override {
        _validateSource(sourceStamp);
    }

    // Signature Standard: EIP-191 - Version Byte: 0x00
    function _validateSource(
        SourceStamp calldata sourceStamp
    ) internal virtual {
        require(!_wasSourceStampNonceUsed[sourceStamp.nonce]);
        require(sourceStamp.deadline >= block.timestamp);
        require(sourceStamp.source == address(this));
        require(sourceStamp.signature.length == EC_SIGNATURE_LENGTH);
        _wasSourceStampNonceUsed[sourceStamp.nonce] = true;
        bytes32 sourceStampHash = keccak256(
            abi.encodePacked(
                EIP191_VERSION_BYTE_0X00_HEADER, sourceStamp.source, sourceStamp.nonce, sourceStamp.deadline
            )
        );
        bytes32 r;
        bytes32 s;
        uint8 v;
        bytes memory signature = sourceStamp.signature;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        address signer = ecrecover(sourceStampHash, v, r, s);
        require(_isValidSourceStampSigner(signer));
    }

    function _isValidSourceStampSigner(
        address signer
    ) internal virtual returns (bool);
}
