// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";

library CallLib {
    function safecall(address target, bytes memory data) internal returns (bool, bytes memory) {
        (bool success, bytes memory returnData) = target.call(data);
        if (success) {
            require(returnData.length != 0 || target.code.length != 0, Errors.NotAContract());
        }
        return (success, returnData);
    }

    function safecall(address target, uint256 value, bytes memory data) internal returns (bool, bytes memory) {
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        if (success) {
            require(returnData.length != 0 || target.code.length != 0, Errors.NotAContract());
        }
        return (success, returnData);
    }
}
