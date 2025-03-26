// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IPostAction} from "contracts/extensions/actions/ActionHub.sol";
import {RecipientData} from "contracts/core/types/Types.sol";

/**
 * @notice A storage struct containing all data regarding a post's collect action.
 *
 * @param amount The collecting cost associated with this publication. 0 for free collect.
 * @param collectLimit The maximum number of collects for this publication. 0 for no limit.
 * @param token The token associated with this publication.
 * @param currentCollects The current number of collects for this publication.
 * @param recipients Recipients of collect amount.
 * @param endTimestamp The end timestamp after which collecting is impossible. 0 for no expiry.
 * @param referralFeeBps The referral fee in basis points.
 * @param followerOnlyGraph  The graph that holds the follow relations that restrict who can collect this post.
 * @param collectionAddress The address of the collectible ERC721 contract.
 * @param isImmutable If true, it means that:
 *          - The Post URI is snapshotted at configuration time and cannot be changed later.
 *          - Collected posts' NFTs remain permanently available.
 *          - What you see is what you get; editing the Post URI or deleting the post will disable collection.
 *         Note: This immutability is only guaranteed if the URI is hosted on immutable storage. Mutability inherent
 *         to the chosen storage technology exceeds the on-chain verification capabilities.
 * @param isDisabled Whether the collect action is disabled or not.
 */
struct CollectActionData {
    uint160 amount;
    uint96 collectLimit;
    address token;
    uint96 currentCollects;
    RecipientData[] recipients;
    uint72 endTimestamp;
    uint16 referralFeeBps;
    address followerOnlyGraph;
    address collectionAddress;
    bool isImmutable;
    bool isDisabled;
}

interface ISimpleCollectAction is IPostAction {
    function getCollectActionData(address feed, uint256 postId) external view returns (CollectActionData memory);
}
