// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {UNIVERSAL_ACTION_MAGIC_VALUE} from "./../../dashboard/actions/ActionHub.sol";

abstract contract BaseAction {
    address immutable ACTION_HUB;

    modifier onlyActionHub() {
        require(msg.sender == ACTION_HUB);
        _;
    }

    constructor(
        address actionHub
    ) {
        ACTION_HUB = actionHub;
    }

    function _configureUniversalAction(
        address originalMsgSender
    ) internal onlyActionHub returns (bytes memory) {
        // uint256(keccak256("lens.core.storage.action.universal.configured"));
        uint256 UNIVERSAL_CONFIGURED_SLOT = uint256(0x0c15cbaf7a02c80aa477dd966ee255b2a1af32b54b8ade0c0a6bbed64aa9142c);
        bool configured;
        assembly {
            configured := sload(UNIVERSAL_CONFIGURED_SLOT)
        }
        require(!configured);
        require(originalMsgSender == address(0));
        assembly {
            sstore(UNIVERSAL_CONFIGURED_SLOT, 1)
        }
        return abi.encode(UNIVERSAL_ACTION_MAGIC_VALUE);
    }
}
