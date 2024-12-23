// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue} from "./../../core/types/Types.sol";

interface IPostAction {
    function configure(
        address originalMsgSender,
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) external returns (bytes memory);

    function execute(
        address originalMsgSender,
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) external returns (bytes memory);
}

interface IAccountAction {
    function configure(
        address originalMsgSender,
        address account,
        KeyValue[] calldata params
    ) external returns (bytes memory);

    function execute(
        address originalMsgSender,
        address account,
        KeyValue[] calldata params
    ) external returns (bytes memory);
}

contract ActionHub {
    event Lens_ActionHub_PostAction_Configured(
        address indexed msgSender, address indexed feed, uint256 indexed postId, KeyValue[] params, bytes returnData
    );

    event Lens_ActionHub_PostAction_Executed(
        address indexed msgSender, address indexed feed, uint256 indexed postId, KeyValue[] params, bytes returnData
    );

    event Lens_ActionHub_AccountAction_Configured(
        address indexed msgSender, address indexed account, KeyValue[] params, bytes returnData
    );

    event Lens_ActionHub_AccountAction_Executed(
        address indexed msgSender, address indexed account, KeyValue[] params, bytes returnData
    );

    function configurePostAction(
        address action,
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) external payable returns (bytes memory) {
        bytes memory returnData = IPostAction(action).configure(msg.sender, feed, postId, params);
        emit Lens_ActionHub_PostAction_Configured(msg.sender, feed, postId, params, returnData);
        return returnData;
    }

    function executePostAction(
        address action,
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) external payable returns (bytes memory) {
        bytes memory returnData = IPostAction(action).execute(msg.sender, feed, postId, params);
        emit Lens_ActionHub_PostAction_Executed(msg.sender, feed, postId, params, returnData);
        return returnData;
    }

    function configureAccountAction(
        address action,
        address account,
        KeyValue[] calldata params
    ) external payable returns (bytes memory) {
        bytes memory returnData = IAccountAction(action).configure(msg.sender, account, params);
        emit Lens_ActionHub_AccountAction_Configured(msg.sender, account, params, returnData);
        return returnData;
    }

    function executeAccountAction(
        address action,
        address account,
        KeyValue[] calldata params
    ) external payable returns (bytes memory) {
        bytes memory returnData = IAccountAction(action).execute(msg.sender, account, params);
        emit Lens_ActionHub_AccountAction_Executed(msg.sender, account, params, returnData);
        return returnData;
    }
}
