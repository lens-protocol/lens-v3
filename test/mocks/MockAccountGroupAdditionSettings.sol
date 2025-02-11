// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IAccountGroupAdditionSettings} from "@core/interfaces/IAccountGroupAdditionSettings.sol";
import {KeyValue} from "@core/types/Types.sol";

contract MockAccountGroupAdditionSettings is IAccountGroupAdditionSettings {
    function testMockAccountGroupAdditionSettings() public {
        // Prevents being counted in Foundry Coverage
    }

    mapping(address => bool) _canBeAddedToGroup;

    function canBeAddedToGroup(address group, address, /* addedBy */ KeyValue[] calldata /* params */ )
        external
        view
        override
        returns (bool)
    {
        return _canBeAddedToGroup[group];
    }

    function mockCanBeAddedToGroup(address group, bool canBeAddedToGroupMock) external {
        _canBeAddedToGroup[group] = canBeAddedToGroupMock;
    }
}
