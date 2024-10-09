// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UsernameTokenized {
    event Lens_Username_MetadataURISet(string metadataURI);

    event Lens_Username_TokenURISet(string tokenURI);

    event Lens_Username_Minted(address indexed to, uint256 indexed tokenId, string indexed username);

    event Lens_Username_Burnt(uint256 indexed tokenId, string indexed username);

    // TODO: This should be separated into receiver and amount probably (cause royalties have two functions)
    event Lens_Username_Royalty(address to, uint256 basisPoints);

    event Lens_Username_MinLengthSet(uint8 length);

    event Lens_Username_MaxLengthSet(uint8 length);

    event Lens_Username_Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
}
