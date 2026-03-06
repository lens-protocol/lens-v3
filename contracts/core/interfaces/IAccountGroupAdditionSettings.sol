// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";

interface IAccountGroupAdditionSettings {
    function canBeAddedToGroup(address group, address addedBy, KeyValue[] calldata params)
        external
        view
        returns (bool);
}
