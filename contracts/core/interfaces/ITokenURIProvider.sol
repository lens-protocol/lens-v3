// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

interface ITokenURIProvider {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
