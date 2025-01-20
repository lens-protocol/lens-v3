// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {UNIVERSAL_ACTION_MAGIC_VALUE} from "contracts/extensions/actions/ActionHub.sol";
import {Errors} from "contracts/core/types/Errors.sol";

abstract contract BaseAction {
    address immutable ACTION_HUB;

    /// @custom:keccak lens.storage.Action.configured
    bytes32 constant STORAGE__ACTION_CONFIGURED = 0x852bead036b7ef35b8026346140cc688bafe817a6c3491812e6d994b1bcda6d9;

    modifier onlyActionHub() {
        require(msg.sender == ACTION_HUB, Errors.InvalidMsgSender());
        _;
    }

    constructor(address actionHub) {
        ACTION_HUB = actionHub;
    }

    function _configureUniversalAction(address originalMsgSender) internal onlyActionHub returns (bytes memory) {
        bool configured;
        assembly {
            configured := sload(STORAGE__ACTION_CONFIGURED)
        }
        require(!configured, Errors.RedundantStateChange());
        require(originalMsgSender == address(0), Errors.InvalidParameter());
        assembly {
            sstore(STORAGE__ACTION_CONFIGURED, 1)
        }
        return abi.encode(UNIVERSAL_ACTION_MAGIC_VALUE);
    }
}
