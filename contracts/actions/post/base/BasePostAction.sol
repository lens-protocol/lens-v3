// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue} from "./../../../core/types/Types.sol";
import {BaseAction} from "./../../base/BaseAction.sol";
import {IPostAction} from "./../../../dashboard/actions/ActionHub.sol";

abstract contract BasePostAction is BaseAction, IPostAction {
    constructor(address actionHub) BaseAction(actionHub) {}

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

    function disable(
        address originalMsgSender,
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) external override onlyActionHub returns (bytes memory) {
        return _disable(originalMsgSender, feed, postId, params);
    }

    function _configure(
        address originalMsgSender,
        address, /* feed */
        uint256, /* postId */
        KeyValue[] calldata /* params */
    ) internal virtual returns (bytes memory) {
        return _configureUniversalAction(originalMsgSender);
    }

    function _execute(
        address originalMsgSender,
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) internal virtual returns (bytes memory);

    function _disable(
        address, /* originalMsgSender */
        address, /* feed */
        uint256, /* postId */
        KeyValue[] calldata /* params */
    ) internal virtual returns (bytes memory) {
        revert();
    }
}
