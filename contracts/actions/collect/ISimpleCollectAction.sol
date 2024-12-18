// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IPostAction} from "./../../core/interfaces/IPostAction.sol";

/**
 * @notice A storage struct containing all data regarding a post's collect action.
 *
 * @param amount The collecting cost associated with this publication. 0 for free collect.
 * @param collectLimit The maximum number of collects for this publication. 0 for no limit.
 * @param currency The currency associated with this publication.
 * @param currentCollects The current number of collects for this publication.
 * @param recipient Recipient of collect fees.
 * @param endTimestamp The end timestamp after which collecting is impossible. 0 for no expiry.
 * @param collectionAddress The address of the collectible ERC721 contract.
 */
struct CollectActionData {
    uint160 amount;
    uint96 collectLimit;
    address currency;
    uint96 currentCollects;
    address recipient;
    uint72 endTimestamp;
    address followerOnlyGraph;
    address collectionAddress;
    bool isImmutable;
}

interface ISimpleCollectAction is IPostAction {
    function getCollectActionData(address feed, uint256 postId) external view returns (CollectActionData memory);
}
