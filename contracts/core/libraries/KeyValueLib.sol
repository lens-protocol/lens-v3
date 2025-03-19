// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue} from "../types/Types.sol";

library KeyValueLib {
    // TODO: Replace for an optimized version later. Copying chunks of calldata into memory directly.
    function concat(KeyValue[] calldata start, KeyValue[] calldata end) internal pure returns (KeyValue[] memory) {
        KeyValue[] memory concatenated = new KeyValue[](start.length + end.length);
        for (uint256 i = 0; i < start.length; i++) {
            concatenated[i] = start[i];
        }
        for (uint256 i = 0; i < end.length; i++) {
            concatenated[start.length + i] = end[i];
        }
        return concatenated;
    }
}
