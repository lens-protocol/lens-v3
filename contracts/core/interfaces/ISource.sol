// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {SourceStamp} from "contracts/core/types/Types.sol";

interface ISource {
    function getTreasury() external view returns (address);

    function validateSource(SourceStamp calldata sourceStamp) external;
}
