// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";

interface IPostAction {
    function configure(address originalMsgSender, address feed, uint256 postId, KeyValue[] calldata params)
        external
        returns (bytes memory);

    function execute(address originalMsgSender, address feed, uint256 postId, KeyValue[] calldata params)
        external
        returns (bytes memory);

    function setDisabled(
        address originalMsgSender,
        address feed,
        uint256 postId,
        bool isDisabled,
        KeyValue[] calldata params
    ) external returns (bytes memory);
}

interface IAccountAction {
    function configure(address originalMsgSender, address account, KeyValue[] calldata params)
        external
        returns (bytes memory);

    function execute(address originalMsgSender, address account, KeyValue[] calldata params)
        external
        returns (bytes memory);

    function setDisabled(address originalMsgSender, address account, bool isDisabled, KeyValue[] calldata params)
        external
        returns (bytes memory);
}

/// @custom:keccak lens.constant.UniversalAction
bytes32 constant UNIVERSAL_ACTION_MAGIC_VALUE = 0xa12c06eea999f2a08fb2bd50e396b2a286921eebbda81fb45a0adcf13afb18ef;

contract ActionHub {
    event Lens_ActionHub_PostAction_Universal(address indexed action);

    event Lens_ActionHub_PostAction_Configured(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_PostAction_Executed(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_PostAction_Disabled(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_PostAction_Enabled(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_AccountAction_Universal(address indexed action);

    event Lens_ActionHub_AccountAction_Configured(
        address indexed action, address indexed msgSender, address indexed account, KeyValue[] params, bytes returnData
    );

    event Lens_ActionHub_AccountAction_Executed(
        address indexed action, address indexed msgSender, address indexed account, KeyValue[] params, bytes returnData
    );

    event Lens_ActionHub_AccountAction_Disabled(
        address indexed action, address indexed msgSender, address indexed account, KeyValue[] params, bytes returnData
    );

    event Lens_ActionHub_AccountAction_Enabled(
        address indexed action, address indexed msgSender, address indexed account, KeyValue[] params, bytes returnData
    );

    function signalUniversalPostAction(address action) external {
        bytes memory returnData = IPostAction(action).configure(address(0), address(0), 0, new KeyValue[](0));
        require(abi.decode(returnData, (bytes32)) == UNIVERSAL_ACTION_MAGIC_VALUE);
        emit Lens_ActionHub_PostAction_Universal(action);
    }

    function configurePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        bytes memory returnData = IPostAction(action).configure(msg.sender, feed, postId, params);
        emit Lens_ActionHub_PostAction_Configured(action, msg.sender, feed, postId, params, returnData);
        return returnData;
    }

    function executePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        bytes memory returnData = IPostAction(action).execute(msg.sender, feed, postId, params);
        emit Lens_ActionHub_PostAction_Executed(action, msg.sender, feed, postId, params, returnData);
        return returnData;
    }

    function disablePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        bytes memory returnData = IPostAction(action).setDisabled(msg.sender, feed, postId, true, params);
        emit Lens_ActionHub_PostAction_Disabled(action, msg.sender, feed, postId, params, returnData);
        return returnData;
    }

    function enablePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        bytes memory returnData = IPostAction(action).setDisabled(msg.sender, feed, postId, false, params);
        emit Lens_ActionHub_PostAction_Enabled(action, msg.sender, feed, postId, params, returnData);
        return returnData;
    }

    function signalUniversalAccountAction(address action) external {
        bytes memory returnData = IAccountAction(action).configure(address(0), address(0), new KeyValue[](0));
        require(abi.decode(returnData, (bytes32)) == UNIVERSAL_ACTION_MAGIC_VALUE);
        emit Lens_ActionHub_AccountAction_Universal(action);
    }

    function configureAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        bytes memory returnData = IAccountAction(action).configure(msg.sender, account, params);
        emit Lens_ActionHub_AccountAction_Configured(action, msg.sender, account, params, returnData);
        return returnData;
    }

    function executeAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        bytes memory returnData = IAccountAction(action).execute(msg.sender, account, params);
        emit Lens_ActionHub_AccountAction_Executed(action, msg.sender, account, params, returnData);
        return returnData;
    }

    function disableAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        bytes memory returnData = IAccountAction(action).setDisabled(msg.sender, account, true, params);
        emit Lens_ActionHub_AccountAction_Disabled(action, msg.sender, account, params, returnData);
        return returnData;
    }

    function enableAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        bytes memory returnData = IAccountAction(action).setDisabled(msg.sender, account, false, params);
        emit Lens_ActionHub_AccountAction_Enabled(action, msg.sender, account, params, returnData);
        return returnData;
    }
}
