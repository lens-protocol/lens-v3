// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";

library CallLib {
    function safecall(address target, uint256 value, bytes memory data) internal returns (bool, bytes memory) {
        (bool callSucceeded, bytes memory returnData) = target.call{value: value}(data);
        if (callSucceeded) {
            require(returnData.length != 0 || target.code.length != 0, Errors.NotAContract());
        }
        return (callSucceeded, returnData);
    }

    function handledcall(address target, uint256 value, bytes memory data) internal returns (bytes memory) {
        (bool callSucceeded, bytes memory returnData) = target.call{value: value}(data);
        return _handleCall(callSucceeded, returnData);
    }

    function handledsafecall(address target, uint256 value, bytes memory data) internal returns (bytes memory) {
        (bool callSucceeded, bytes memory returnData) = safecall(target, value, data);
        return _handleCall(callSucceeded, returnData);
    }

    function safecall(address target, bytes memory data) internal returns (bool, bytes memory) {
        return safecall(target, 0, data);
    }

    function handledcall(address target, bytes memory data) internal returns (bytes memory) {
        return handledcall(target, 0, data);
    }

    function handledsafecall(address target, bytes memory data) internal returns (bytes memory) {
        return handledsafecall(target, 0, data);
    }

    function _handleCall(bool callSucceeded, bytes memory returnData) private pure returns (bytes memory) {
        if (!callSucceeded) {
            assembly {
                // Get the length of the return data, which contains the error message or selector, as the call failed
                let length := mload(returnData)
                // If the returned data length is greater than zero...
                if iszero(iszero(length)) {
                    // ...revert with the same error message or selector
                    revert(add(returnData, 32), length)
                }
                // else, revert without any error message nor selector
                revert(0, 0)
            }
        }
        return returnData;
    }
}
