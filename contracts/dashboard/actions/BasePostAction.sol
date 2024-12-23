// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue} from "./../../core/types/Types.sol";
import {BaseAction} from "./BaseAction.sol";
import {IPostAction} from "./ActionHub.sol";

abstract contract BasePostAction is BaseAction, IPostAction {
    function configure(
        address originalMsgSender,
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) external override onlyActionHub returns (bytes memory) {
        return _configure(originalMsgSender, feed, postId, params);
    }

    function execute(
        address originalMsgSender,
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) external override onlyActionHub returns (bytes memory) {
        return _execute(originalMsgSender, feed, postId, params);
    }

    function _configure(
        address originalMsgSender,
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) internal virtual returns (bytes memory);

    function _execute(
        address originalMsgSender,
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) internal virtual returns (bytes memory);
}
