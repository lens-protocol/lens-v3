// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNft is ERC721 {
    function testMockNft() public {
        // Prevents being included in the foundry coverage report
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId, bytes memory _data) external {
        _safeMint(to, tokenId, _data);
    }

    function mint(uint256 tokenId) external {
        _mint(msg.sender, tokenId);
    }

    function safeMint(uint256 tokenId) external {
        _safeMint(msg.sender, tokenId);
    }

    function safeMint(uint256 tokenId, bytes memory _data) external {
        _safeMint(msg.sender, tokenId, _data);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}
