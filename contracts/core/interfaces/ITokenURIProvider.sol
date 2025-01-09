// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

interface ITokenURIProvider {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
