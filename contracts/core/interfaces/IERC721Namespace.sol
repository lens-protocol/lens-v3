// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IERC721} from "contracts/core/interfaces/IERC721.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";

interface IERC721Namespace is INamespace, IERC721 {
    function exists(uint256 tokenId) external view returns (bool);

    function getTokenIdByUsername(string calldata username) external view returns (uint256);

    function getUsernameByTokenId(uint256 tokenId) external view returns (string memory);
}
