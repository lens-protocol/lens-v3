// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "contracts/core/base/LensERC721.sol";
import {IERC7572} from "contracts/actions/post/collect/IERC7572.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {ITokenURIProvider} from "contracts/core/interfaces/ITokenURIProvider.sol";
import {Errors} from "contracts/core/types/Errors.sol";

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
    event Lens_LensCollectedPost_Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    string internal _contentURISnapshot;
    string internal _contractURI;
    address internal immutable _feed;
    uint256 internal immutable _postId;
    address internal immutable _collectAction;

    constructor(address feed, uint256 postId, bool isImmutable) {
        LensERC721._initialize("Lens Collected Post", "LCP", ITokenURIProvider(address(0)));
        string memory contentURI = IFeed(feed).getPost(postId).contentURI;
        require(bytes(contentURI).length > 0, Errors.InvalidParameter());
        _feed = feed;
        _postId = postId;
        _contractURI = contentURI;
        _collectAction = msg.sender;
        if (isImmutable) {
            _contentURISnapshot = contentURI;
        }
        emit ContractURIUpdated();
    }

    function mint(address to, uint256 tokenId) external {
        require(msg.sender == _collectAction, Errors.InvalidMsgSender());
        _mint(to, tokenId);
    }

    // Getters

    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 /*tokenId*/ ) public view override returns (string memory) {
        if (bytes(_contentURISnapshot).length > 0) {
            return _contentURISnapshot;
        } else {
            string memory contentURI = IFeed(_feed).getPost(_postId).contentURI;
            // If content was deleted we fail. You can override this to return the empty URI if preferred.
            require(bytes(contentURI).length > 0, Errors.DoesNotExist());
            return contentURI;
        }
    }

    // Internal

    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        emit Lens_LensCollectedPost_Transfer(from, to, tokenId);
    }

    // Disabling integrated LensERC721 tokenURIProvider
    function _beforeTokenURIProviderSet(ITokenURIProvider /* tokenURIProvider */ ) internal pure override {
        revert Errors.NotImplemented();
    }
}
