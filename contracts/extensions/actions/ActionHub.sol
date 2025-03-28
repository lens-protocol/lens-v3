// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {SourceStampBased} from "contracts/core/base/SourceStampBased.sol";

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

contract ActionHub is SourceStampBased {
    event Lens_ActionHub_PostAction_Universal(address indexed action);

    event Lens_ActionHub_PostAction_Configured(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        address postAuthor,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_PostAction_Reconfigured(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        address postAuthor,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_PostAction_Executed(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        address postAuthor,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_PostAction_Disabled(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        address postAuthor,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_PostAction_Enabled(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        address postAuthor,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_AccountAction_Universal(address indexed action);

    event Lens_ActionHub_AccountAction_Configured(
        address indexed action,
        address indexed msgSender,
        address indexed account,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_AccountAction_Reconfigured(
        address indexed action,
        address indexed msgSender,
        address indexed account,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_AccountAction_Executed(
        address indexed action,
        address indexed msgSender,
        address indexed account,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_AccountAction_Disabled(
        address indexed action,
        address indexed msgSender,
        address indexed account,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Lens_ActionHub_AccountAction_Enabled(
        address indexed action,
        address indexed msgSender,
        address indexed account,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    /// @custom:keccak lens.storage.ActionHub.PostActionStatus
    bytes32 constant STORAGE__POST_ACTION_STATUS = 0x5cf5bb5f1a3f0a5fa6642893567684ad97472320c8ebdff0c847f0f5ffa686a8;
    /// @custom:keccak lens.storage.ActionHub.AccountActionStatus
    bytes32 constant STORAGE__ACCOUNT_ACTION_STATUS = 0x882d8e43ef939b6546056e5cc9db6a69e8d4b37be87d42d6b7b0419769e84213;

    struct ActionStatus {
        bool wasConfigured;
        bool isDisabled;
    }

    function $postActionStatus()
        internal
        pure
        returns (mapping(address => mapping(address => mapping(uint256 => ActionStatus))) storage _storage)
    {
        assembly {
            _storage.slot := STORAGE__POST_ACTION_STATUS
        }
    }

    function $accountActionStatus()
        internal
        pure
        returns (mapping(address => mapping(address => ActionStatus)) storage _storage)
    {
        assembly {
            _storage.slot := STORAGE__ACCOUNT_ACTION_STATUS
        }
    }

    function signalUniversalPostAction(address action) external {
        bytes memory returnData = IPostAction(action).configure(address(0), address(0), 0, new KeyValue[](0));
        require(abi.decode(returnData, (bytes32)) == UNIVERSAL_ACTION_MAGIC_VALUE, Errors.UnexpectedContractImpl());
        emit Lens_ActionHub_PostAction_Universal(action);
    }

    function configurePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        bytes memory returnData = IPostAction(action).configure(msg.sender, feed, postId, params);
        address postAuthor = IFeed(feed).getPostAuthor(postId);
        address source = _processSourceStamp(params);
        if ($postActionStatus()[action][feed][postId].wasConfigured == false) {
            $postActionStatus()[action][feed][postId].wasConfigured = true;
            emit Lens_ActionHub_PostAction_Configured(
                action, msg.sender, feed, postId, postAuthor, source, params, returnData
            );
        } else {
            emit Lens_ActionHub_PostAction_Reconfigured(
                action, msg.sender, feed, postId, postAuthor, source, params, returnData
            );
        }
        return returnData;
    }

    function executePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($postActionStatus()[action][feed][postId].isDisabled == false, Errors.Disabled());
        bytes memory returnData = IPostAction(action).execute(msg.sender, feed, postId, params);
        address postAuthor = IFeed(feed).getPostAuthor(postId);
        address source = _processSourceStamp(params);
        emit Lens_ActionHub_PostAction_Executed(action, msg.sender, feed, postId, postAuthor, source, params, returnData);
        return returnData;
    }

    function disablePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($postActionStatus()[action][feed][postId].isDisabled == false, Errors.RedundantStateChange());
        bytes memory returnData = IPostAction(action).setDisabled(msg.sender, feed, postId, true, params);
        $postActionStatus()[action][feed][postId].isDisabled = true;
        address postAuthor = IFeed(feed).getPostAuthor(postId);
        address source = _processSourceStamp(params);
        emit Lens_ActionHub_PostAction_Disabled(action, msg.sender, feed, postId, postAuthor, source, params, returnData);
        return returnData;
    }

    function enablePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($postActionStatus()[action][feed][postId].isDisabled, Errors.RedundantStateChange());
        bytes memory returnData = IPostAction(action).setDisabled(msg.sender, feed, postId, false, params);
        $postActionStatus()[action][feed][postId].isDisabled = false;
        address postAuthor = IFeed(feed).getPostAuthor(postId);
        address source = _processSourceStamp(params);
        emit Lens_ActionHub_PostAction_Enabled(action, msg.sender, feed, postId, postAuthor, source, params, returnData);
        return returnData;
    }

    function signalUniversalAccountAction(address action) external {
        bytes memory returnData = IAccountAction(action).configure(address(0), address(0), new KeyValue[](0));
        require(abi.decode(returnData, (bytes32)) == UNIVERSAL_ACTION_MAGIC_VALUE, Errors.UnexpectedContractImpl());
        emit Lens_ActionHub_AccountAction_Universal(action);
    }

    function configureAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($accountActionStatus()[action][account].isDisabled == false, Errors.Disabled());
        bytes memory returnData = IAccountAction(action).configure(msg.sender, account, params);
        address source = _processSourceStamp(params);
        if ($accountActionStatus()[action][account].wasConfigured == false) {
            $accountActionStatus()[action][account].wasConfigured = true;
            emit Lens_ActionHub_AccountAction_Configured(action, msg.sender, account, source, params, returnData);
        } else {
            emit Lens_ActionHub_AccountAction_Reconfigured(action, msg.sender, account, source, params, returnData);
        }
        return returnData;
    }

    function executeAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($accountActionStatus()[action][account].isDisabled == false, Errors.Disabled());
        bytes memory returnData = IAccountAction(action).execute(msg.sender, account, params);
        address source = _processSourceStamp(params);
        emit Lens_ActionHub_AccountAction_Executed(action, msg.sender, account, source, params, returnData);
        return returnData;
    }

    function disableAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($accountActionStatus()[action][account].isDisabled == false, Errors.RedundantStateChange());
        bytes memory returnData = IAccountAction(action).setDisabled(msg.sender, account, true, params);
        $accountActionStatus()[action][account].isDisabled = true;
        address source = _processSourceStamp(params);
        emit Lens_ActionHub_AccountAction_Disabled(action, msg.sender, account, source, params, returnData);
        return returnData;
    }

    function enableAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($accountActionStatus()[action][account].isDisabled, Errors.RedundantStateChange());
        bytes memory returnData = IAccountAction(action).setDisabled(msg.sender, account, false, params);
        $accountActionStatus()[action][account].isDisabled = false;
        address source = _processSourceStamp(params);
        emit Lens_ActionHub_AccountAction_Enabled(action, msg.sender, account, source, params, returnData);
        return returnData;
    }
}
