// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IPostAction} from "contracts/extensions/actions/ActionHub.sol";

/**
 * @notice A storage struct containing all data regarding a post's collect action.
 *
 * @param amount The collecting cost associated with this publication. 0 for free collect.
 * @param collectLimit The maximum number of collects for this publication. 0 for no limit.
 * @param token The token associated with this publication.
 * @param currentCollects The current number of collects for this publication.
 * @param recipient Recipient of collect fees.
 * @param endTimestamp The end timestamp after which collecting is impossible. 0 for no expiry.
 * @param collectionAddress The address of the collectible ERC721 contract.
 */
struct CollectActionData {
    uint160 amount;
    uint96 collectLimit;
    address token;
    uint96 currentCollects;
    address recipient;
    uint72 endTimestamp;
    address followerOnlyGraph;
    address collectionAddress;
    bool isImmutable;
    bool isDisabled;
}

interface ISimpleCollectAction is IPostAction {
    function getCollectActionData(address feed, uint256 postId) external view returns (CollectActionData memory);
}
