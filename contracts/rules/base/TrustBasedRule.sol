// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";

abstract contract TrustBasedRule {
    event Lens_Rule_Trusted(address indexed account, address indexed trustedAddress);
    event Lens_Rule_Untrusted(address indexed account, address indexed untrustedAddress);

    /// @custom:keccak lens.storage.TrustBasedRule.isTrusted
    bytes32 constant STORAGE__IS_TRUSTED = 0x463a00e6fc84151780a21ba2127d78a0c153372a15d5669ad3912100980952bc;

    function $isTrusted() private pure returns (mapping(address => mapping(address => bool)) storage _storage) {
        assembly {
            _storage.slot := STORAGE__IS_TRUSTED
        }
    }

    function setTrust(address target, bool isTrusted) external virtual {
        $isTrusted()[msg.sender][target] = isTrusted;
        if (isTrusted) {
            emit Lens_Rule_Trusted(msg.sender, target);
        } else {
            emit Lens_Rule_Untrusted(msg.sender, target);
        }
    }

    function _requireTrust(address fromAccount, address toTarget) internal view virtual {
        require(_isTrusted(fromAccount, toTarget), Errors.Untrusted());
    }

    function _isTrusted(address fromAccount, address toTarget) internal view virtual returns (bool) {
        return $isTrusted()[fromAccount][toTarget];
    }
}
