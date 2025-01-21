// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {EIP712EncodingLib} from "contracts/core/libraries/EIP712EncodingLib.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";

// Move to types
struct EIP712Signature {
    address signer;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 nonce;
    uint256 deadline;
}

struct RestrictedSignerMessage {
    bytes4 functionSelector;
    bytes abiEncodedParams;
    uint256 nonce;
    uint256 deadline;
}

abstract contract RestrictedSignersRule is OwnableMetadataBasedRule {
    event Lens_RestrictedSignersRule_SignerAdded(address indexed signer, string label);
    event Lens_RestrictedSignersRule_SignerRemoved(address indexed signer);
    event Lens_RestrictedSignersRule_SignerNonceUsed(address indexed signer, uint256 indexed nonce);

    struct RulesStorage {
        mapping(address => mapping(bytes32 => InnerStorage)) rulesStorage;
    }

    struct InnerStorage {
        mapping(address => bool) isWhitelistedSigner;
        mapping(address => mapping(uint256 => bool)) wasSignerNonceUsed;
    }

    /// @custom:keccak lens.param.restrictedSigners
    bytes32 constant PARAM__RESTRICTED_SIGNERS = 0x49dbb83c2ecd648eb2e855c62ee31e80d5716566338c31ed8b5e70e483511ab6;

    /// @custom:keccak lens.storage.RestrictedSignersRule.RulesStorage
    bytes32 constant STORAGE__RESTRICTED_SIGNERS_RULE =
        0x4e044b499e5458aefc8410057ecfc08c7c44c10d7468c520c4d177f2d15ed6d0;

    function $rulesStorage()
        private
        pure
        returns (mapping(address => mapping(bytes32 => InnerStorage)) storage _storage)
    {
        assembly {
            _storage.slot := STORAGE__RESTRICTED_SIGNERS_RULE
        }
    }

    function $rulesStorage(address primitiveAddress, bytes32 configSalt) private view returns (InnerStorage storage) {
        mapping(address => mapping(bytes32 => InnerStorage)) storage _rulesStorage = $rulesStorage();
        return _rulesStorage[primitiveAddress][configSalt];
    }

    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;
    // keccak256(bytes("1"))
    bytes32 constant EIP712_DOMAIN_VERSION_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 constant EIP712_DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    // keccak256("RestrictedSignerMessage(bytes4 functionSelector,bytes abiEncodedParams,uint256 nonce,uint256 deadline)")
    bytes32 constant RESTRICTED_SIGNER_MESSAGE_TYPEHASH =
        0x7ad50a890590bc3256729acae2904e819ef1a0db262583f09fef8974530accdf;

    constructor(address owner, string memory metadataURI) OwnableMetadataBasedRule(owner, metadataURI) {}

    function _configure(bytes32 configSalt, KeyValue[] calldata ruleParams) internal virtual {
        require(ruleParams.length > 0, Errors.InvalidParameter());
        require(ruleParams[0].key == PARAM__RESTRICTED_SIGNERS, Errors.InvalidParameter());
        (address[] memory signers, string[] memory labels, bool[] memory isWhitelisted) =
            abi.decode(ruleParams[0].value, (address[], string[], bool[]));
        require(signers.length == isWhitelisted.length, Errors.InvalidParameter());
        require(signers.length == labels.length, Errors.InvalidParameter());
        for (uint256 i = 0; i < signers.length; i++) {
            bool wasWhitelisted = $rulesStorage(msg.sender, configSalt).isWhitelistedSigner[signers[i]];
            if (wasWhitelisted == isWhitelisted[i]) {
                if (isWhitelisted[i]) {
                    // Signal removal and re-addition in order to update the label
                    emit Lens_RestrictedSignersRule_SignerRemoved(signers[i]);
                    emit Lens_RestrictedSignersRule_SignerAdded(signers[i], labels[i]);
                }
            } else {
                $rulesStorage(msg.sender, configSalt).isWhitelistedSigner[signers[i]] = isWhitelisted[i];
                if (isWhitelisted[i]) {
                    emit Lens_RestrictedSignersRule_SignerAdded(signers[i], labels[i]);
                } else {
                    emit Lens_RestrictedSignersRule_SignerRemoved(signers[i]);
                }
            }
        }
    }

    function _validateRestrictedSignerMessage(
        bytes32 configSalt,
        bytes4 functionSelector,
        bytes memory abiEncodedFunctionParams,
        EIP712Signature memory signature
    ) internal {
        RestrictedSignerMessage memory message =
            RestrictedSignerMessage(functionSelector, abiEncodedFunctionParams, signature.nonce, signature.deadline);
        if (block.timestamp > signature.deadline) {
            revert Errors.Expired();
        }
        if ($rulesStorage(msg.sender, configSalt).wasSignerNonceUsed[signature.signer][signature.nonce]) {
            revert Errors.NonceUsed();
        }
        $rulesStorage(msg.sender, configSalt).wasSignerNonceUsed[signature.signer][signature.nonce] = true;
        emit Lens_RestrictedSignersRule_SignerNonceUsed(signature.signer, signature.nonce);
        if (!$rulesStorage(msg.sender, configSalt).isWhitelistedSigner[signature.signer]) {
            revert Errors.WrongSigner();
        }
        bytes32 hashStruct = _calculateMessageHashStruct(message);
        bytes32 digest = _calculateDigest(hashStruct);
        _validateRecoveredAddress(digest, signature);
    }

    function _calculateMessageHashStruct(RestrictedSignerMessage memory message) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                RESTRICTED_SIGNER_MESSAGE_TYPEHASH,
                message.functionSelector,
                EIP712EncodingLib.encodeForEIP712(message.abiEncodedParams),
                message.nonce,
                message.deadline
            )
        );
    }

    function _calculateDigest(bytes32 messageHashStruct) private view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _calculateDomainSeparatorHashStruct(), messageHashStruct));
    }

    function _calculateDomainSeparatorHashStruct() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256("Lens Protocol Restricted Signer Rule"),
                EIP712_DOMAIN_VERSION_HASH,
                block.chainid,
                msg.sender // TODO: This is using primitive's address, maybe should be address(this), so it's rule addr
            )
        );
    }

    function _validateRecoveredAddress(bytes32 digest, EIP712Signature memory signature) private view {
        if (block.timestamp > signature.deadline) {
            revert Errors.Expired();
        }
        // If the expected address is a contract, check the signature there.
        if (signature.signer.code.length != 0) {
            bytes memory concatenatedSig = abi.encodePacked(signature.r, signature.s, signature.v);
            if (IERC1271(signature.signer).isValidSignature(digest, concatenatedSig) != EIP1271_MAGIC_VALUE) {
                revert Errors.InvalidSignature();
            }
        } else {
            address recoveredAddress = ecrecover(digest, signature.v, signature.r, signature.s);
            if (recoveredAddress == address(0) || recoveredAddress != signature.signer) {
                revert Errors.WrongSigner();
            }
        }
    }
}
