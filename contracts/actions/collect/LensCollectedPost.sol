// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import "./../../core/base/LensERC721.sol";
import {IERC7572} from "./IERC7572.sol";
import {IFeed} from "./../../core/interfaces/IFeed.sol";
import {ITokenURIProvider} from "./../../core/interfaces/ITokenURIProvider.sol";

/**
 * @notice A contract that represents a Lens Collected Post.
 *
 * @dev This contract is used to store the metadata of a Lens Collected Post.
 * It inherits from LensERC721 and implements the IERC7572 interface.
 * The contractURI() function returns the contract-level metadata making it compatible with the EIP-7572 proposed
 * standard and useful for dapps and offchain indexers to show rich information about the post itself.
 *
 * If the Collect is immutable - it will snapshot the content of the post and always return the snapshotted tokenURI
 * even if the post was updated or deleted. The contractURI, however, always stays the same, as it was at the moment of
 * Collect creation.
 */
contract LensCollectedPost is LensERC721, IERC7572 {
    string internal _contentURISnapshot;
    string internal _contractURI;
    address internal immutable _feed;
    uint256 internal immutable _postId;
    bool internal immutable _isImmutable; // TODO:"" This can be replaced with bytes(_contentURISnapshot).length
    address internal immutable _collectAction;

    constructor(
        address feed,
        uint256 postId,
        bool isImmutable
    ) LensERC721("Lens Collected Post", "LCP", ITokenURIProvider(address(0))) {
        string memory contentURI = IFeed(feed).getPost(postId).contentURI;
        require(bytes(contentURI).length > 0, "Post content URI is empty");
        _feed = feed;
        _postId = postId;
        _isImmutable = isImmutable;
        _contractURI = contentURI;
        _collectAction = msg.sender;
        if (isImmutable) {
            _contentURISnapshot = contentURI;
        }
        emit ContractURIUpdated();
    }

    function mint(address to, uint256 tokenId) external {
        require(msg.sender == _collectAction, "Only CollectAction can mint");
        _mint(to, tokenId);
    }

    // Getters

    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 /*tokenId*/ ) public view override returns (string memory) {
        if (_isImmutable) {
            return _contentURISnapshot;
        } else {
            string memory contentURI = IFeed(_feed).getPost(_postId).contentURI;
            // TODO: If content was deleted - should we fail or return empty string?
            require(bytes(contentURI).length > 0);
            return contentURI;
        }
    }

    // Internal

    // Disabling integrated LensERC721 tokenURIProvider
    // TODO: Is this approach more favorable than deploying the LensCollectedPostTokenURIProvider over and over?
    function _beforeTokenURIProviderSet(ITokenURIProvider /* tokenURIProvider */ ) internal pure override {
        revert();
    }
}
