// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {
    ISimpleCollectAction,
    CollectActionConfigureParams,
    CollectActionExecutionParams,
    CollectActionData,
    CollectActionData
} from "./ISimpleCollectAction.sol";
import {IFeed} from "./../../core/interfaces/IFeed.sol";
import {IGraph} from "./../../core/interfaces/IGraph.sol";

import {LensCollectedPost} from "./LensCollectedPost.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SimpleCollectAction is ISimpleCollectAction {
    using SafeERC20 for IERC20;

    struct CollectActionStorage {
        mapping(address => mapping(uint256 => CollectActionData)) collectData;
    }

    // keccak256('lens.simple.collect.action.storage')
    bytes32 constant SIMPLE_COLLECT_ACTION_STORAGE_SLOT =
        0xec3c61dac83a5e1c58a4edc68a1b1d187690a6379142dd5c3c7be1006dbe60f7;

    function $collectDataStorage() private pure returns (CollectActionStorage storage _storage) {
        assembly {
            _storage.slot := SIMPLE_COLLECT_ACTION_STORAGE_SLOT
        }
    }

    function configure(address feed, uint256 postId, bytes calldata data) external override returns (bytes memory) {
        _validateSenderIsAuthor(msg.sender, feed, postId);

        CollectActionConfigureParams memory configData = abi.decode(data, (CollectActionConfigureParams));
        _validateConfigureParams(configData);

        CollectActionData storage storedData = $collectDataStorage().collectData[feed][postId];

        if (storedData.collectionAddress == address(0)) {
            // First time?
            // create and deploy the Lens Collected Post contract
            address collectionAddress = address(new LensCollectedPost(feed, postId, configData.isImmutable));
            _storeCollectParams(feed, postId, configData, collectionAddress);
        } else {
            // Editing existing collect action config
            if (storedData.isImmutable) {
                // TODO: Should we have two different bools? isImmutableConfig & isImmutableContentURI?
                revert("Cannot edit immutable collect");
            } else {
                storedData.amount = configData.amount;
                storedData.collectLimit = configData.collectLimit;
                storedData.currency = configData.currency;
                storedData.recipient = configData.recipient;
                storedData.followerOnlyGraph = configData.followerOnlyGraph;
                storedData.endTimestamp = configData.endTimestamp;
                // storedData.isImmutable = configData.isImmutable;
                // TODO: Cannot make it immutable if it wasn't before, because ContentURI is not immutable, unless we
                // would figure out a way to trigger a switch in LensCollectedPost contract.
            }
        }
        emit Lens_PostAction_Configured(feed, postId, abi.encode(data, storedData)); // TODO: Should we emit just one?
        return data;
    }

    function execute(address feed, uint256 postId, bytes calldata data) external override returns (bytes memory) {
        CollectActionExecutionParams memory expectedParams = abi.decode(data, (CollectActionExecutionParams));

        CollectActionData storage storedData = $collectDataStorage().collectData[feed][postId];
        storedData.currentCollects++;

        _validateCollect(feed, postId, expectedParams);

        _processCollect(feed, postId);

        // TODO: Might want to move inside _processCollect?
        LensCollectedPost(storedData.collectionAddress).mint(msg.sender, storedData.currentCollects);

        emit Lens_PostAction_Executed(feed, postId, data);
        return data;
    }

    function getCollectActionData(address feed, uint256 postId) external view returns (CollectActionData memory) {
        return $collectDataStorage().collectData[feed][postId];
    }

    function _validateSenderIsAuthor(address sender, address feed, uint256 postId) internal virtual {
        if (sender != IFeed(feed).getPostAuthor(postId)) {
            revert("Sender is not the author");
        }
    }

    function _validateConfigureParams(CollectActionConfigureParams memory configData) internal virtual {
        if (configData.amount == 0) {
            require(configData.currency == address(0), "Invalid currency");
        } else {
            require(configData.currency != address(0), "Invalid currency");
        }
        if (configData.endTimestamp != 0 && configData.endTimestamp < block.timestamp) {
            revert("Invalid params");
        }
        if (configData.followerOnlyGraph != address(0)) {
            // Check if the Graph supports isFollowing() interface
            IGraph(configData.followerOnlyGraph).isFollowing(address(this), msg.sender);
        }
    }

    function _storeCollectParams(
        address feed,
        uint256 postId,
        CollectActionConfigureParams memory configData,
        address collectionAddress
    ) internal virtual {
        $collectDataStorage().collectData[feed][postId] = CollectActionData({
            amount: configData.amount,
            collectLimit: configData.collectLimit,
            currency: configData.currency,
            currentCollects: 0,
            recipient: configData.recipient,
            endTimestamp: configData.endTimestamp,
            followerOnlyGraph: configData.followerOnlyGraph,
            collectionAddress: collectionAddress,
            isImmutable: configData.isImmutable
        });
    }

    function _validateCollect(
        address feed,
        uint256 postId,
        CollectActionExecutionParams memory expectedParams
    ) internal virtual {
        CollectActionData storage data = $collectDataStorage().collectData[feed][postId];

        require(data.collectionAddress != address(0), "Collect not configured for this post");

        if (data.endTimestamp != 0 && block.timestamp > data.endTimestamp) {
            revert("Collect expired");
        }

        if (data.collectLimit != 0 && data.currentCollects + 1 > data.collectLimit) {
            revert("Collect limit exceeded");
        }

        if (expectedParams.amount != data.amount || expectedParams.currency != data.currency) {
            revert("Invalid expected amount and/or currency");
        }

        if (data.followerOnlyGraph != address(0)) {
            require(
                IGraph(data.followerOnlyGraph).isFollowing(msg.sender, IFeed(feed).getPostAuthor(postId)),
                "Not following"
            );
        }

        if (data.isImmutable) {
            // TODO: There might be some edge-cases here (e.g. maybe also worth checking LensCollectedPost.isImmutable)
            string memory contentURI = IFeed(feed).getPost(postId).contentURI;
            require(
                keccak256(bytes(contentURI))
                    == keccak256(bytes(LensCollectedPost(data.collectionAddress).tokenURI(data.currentCollects))),
                "Invalid content URI"
            );
        }
    }

    function _processCollect(address feed, uint256 postId) internal virtual {
        CollectActionData storage data = $collectDataStorage().collectData[feed][postId];

        uint256 amount = data.amount;
        address currency = data.currency;
        address recipient = data.recipient;

        if (amount > 0) {
            IERC20(currency).safeTransferFrom(msg.sender, recipient, amount);
        }
    }
}
