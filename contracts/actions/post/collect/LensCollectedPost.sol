// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "contracts/core/base/LensERC721.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {ITokenURIProvider} from "contracts/core/interfaces/ITokenURIProvider.sol";
import {Errors} from "contracts/core/types/Errors.sol";

struct ContentURISnapshot {
    string contentURI;
    uint256 tokenId;
}

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
 *
 * We assume tokenIds are sequential and start from 1.
 */
contract LensCollectedPost is LensERC721 {
    event Lens_LensCollectedPost_Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ContentURISnapshot[] internal _contentURISnapshots;
    bool internal _isImmutable;
    address internal immutable FEED;
    uint256 internal immutable POST_ID;
    address internal immutable COLLECT_ACTION;

    constructor(address feed, uint256 postId, bool isImmutableCollect) {
        LensERC721._initialize("Lens Collected Post", "LCP", ITokenURIProvider(address(0)));
        COLLECT_ACTION = msg.sender;
        FEED = feed;
        POST_ID = postId;
        if (isImmutableCollect) {
            _turnImmutable(_getNonEmptyContentURIFromPost());
        }
    }

    function mint(address to, uint256 tokenId) external {
        require(msg.sender == COLLECT_ACTION, Errors.InvalidMsgSender());
        _takeContentURISnapshotIfNeeded(tokenId);
        _mint(to, tokenId);
    }

    function turnImmutable() external {
        require(msg.sender == COLLECT_ACTION, Errors.InvalidMsgSender());
        if (!_isImmutable) {
            _turnImmutable(_getNonEmptyContentURIFromPost());
        }
    }

    // Getters

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_isImmutable) {
            // Searching for snapshots (starting from latest)
            for (uint256 i = _contentURISnapshots.length - 1; i > 0; i--) {
                if (_contentURISnapshots[i].tokenId <= tokenId) {
                    return _contentURISnapshots[i].contentURI;
                }
            }
            // contentURISnapshot[0] is always taken when the collection is marked as immutable,
            // so we can guarantee it's present and non-empty.
            return _contentURISnapshots[0].contentURI;
        } else {
            return _getNonEmptyContentURIFromPost();
        }
    }

    function getPostId() external view returns (uint256) {
        return POST_ID;
    }

    function isImmutable() external view returns (bool) {
        return _isImmutable;
    }

    // Internal

    function _getNonEmptyContentURIFromPost() internal view returns (string memory) {
        string memory contentURI = IFeed(FEED).getPost(POST_ID).contentURI;
        require(bytes(contentURI).length > 0, Errors.InvalidParameter());
        return contentURI;
    }

    function _turnImmutable(string memory contentURI) internal {
        _isImmutable = true;
        _contentURISnapshots.push(ContentURISnapshot(contentURI, 0));
    }

    function _takeContentURISnapshotIfNeeded(uint256 tokenId) internal {
        if (_isImmutable) {
            // Getting the content URI will revert if the post was deleted or does not exist.
            string memory contentURI = _getNonEmptyContentURIFromPost();
            string memory latestContentURISnapshot = _contentURISnapshots[_contentURISnapshots.length - 1].contentURI;
            if (keccak256(bytes(contentURI)) != keccak256(bytes(latestContentURISnapshot))) {
                _contentURISnapshots.push(ContentURISnapshot(contentURI, tokenId));
            }
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        emit Lens_LensCollectedPost_Transfer(from, to, tokenId);
    }

    // Disabling integrated LensERC721 tokenURIProvider
    function _beforeTokenURIProviderSet(ITokenURIProvider /* tokenURIProvider */ ) internal pure override {
        revert Errors.NotImplemented();
    }
}
