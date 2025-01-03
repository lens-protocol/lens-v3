// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue} from "./../../../core/types/Types.sol";
import {BaseAction} from "./../../base/BaseAction.sol";
import {IAccountAction} from "./../../../dashboard/actions/ActionHub.sol";

abstract contract BaseAccountAction is BaseAction, IAccountAction {
    constructor(address actionHub) BaseAction(actionHub) {}

    function configure(address originalMsgSender, address account, KeyValue[] calldata params)
        external
        override
        onlyActionHub
        returns (bytes memory)
    {
        return _configure(originalMsgSender, account, params);
    }

    function execute(address originalMsgSender, address account, KeyValue[] calldata params)
        external
        override
        onlyActionHub
        returns (bytes memory)
    {
        return _execute(originalMsgSender, account, params);
    }

    function setDisabled(address originalMsgSender, address account, bool isDisabled, KeyValue[] calldata params)
        external
        override
        onlyActionHub
        returns (bytes memory)
    {
        return _setDisabled(originalMsgSender, account, isDisabled, params);
    }

    function _configure(address originalMsgSender, address, /* account */ KeyValue[] calldata /* params */ )
        internal
        virtual
        returns (bytes memory)
    {
        return _configureUniversalAction(originalMsgSender);
    }

    function _execute(address originalMsgSender, address account, KeyValue[] calldata params)
        internal
        virtual
        returns (bytes memory);

    function _setDisabled(
        address, /* originalMsgSender */
        address, /* account */
        bool, /* isDisabled */
        KeyValue[] calldata /* params */
    ) internal virtual returns (bytes memory) {
        revert();
    }
}
