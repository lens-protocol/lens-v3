// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";

interface IERC721Namespace is INamespace, IERC721 {
    event Lens_Username_Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function exists(uint256 tokenId) external view returns (bool);

    function getTokenIdByUsername(string calldata username) external view returns (uint256);

    function getUsernameByTokenId(uint256 tokenId) external view returns (string memory);
}
