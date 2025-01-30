// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Follow} from "contracts/core/interfaces/IGraph.sol";
import {Errors} from "contracts/core/types/Errors.sol";

library GraphCore {
    // Storage

    struct Storage {
        mapping(address => uint256) lastFollowIdAssigned;
        mapping(address => mapping(address => Follow)) follows;
        mapping(address => mapping(uint256 => address)) followers;
        mapping(address => uint256) followersCount;
        mapping(address => uint256) followingCount;
    }

    /// @custom:keccak lens.storage.GraphCore
    bytes32 constant STORAGE__GRAPH_CORE = 0x5863e3ed01973a22e9d816ccf1175242559c6aa633e210d5eef6ba360542fe03;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__GRAPH_CORE
        }
    }

    // Internal functions - Use these functions to be called as an inlined library

    function _follow(address followerAccount, address accountToFollow, uint256 followId, uint256 timestamp)
        internal
        returns (uint256)
    {
        require(followerAccount != address(0), Errors.InvalidParameter());
        require(accountToFollow != address(0), Errors.InvalidParameter());
        require(followerAccount != accountToFollow, Errors.ActionOnSelf());
        require($storage().follows[followerAccount][accountToFollow].id == 0, Errors.CannotFollowAgain());
        if (followId == 0) {
            followId = ++$storage().lastFollowIdAssigned[accountToFollow];
        } else {
            require(followId <= $storage().lastFollowIdAssigned[accountToFollow], Errors.InvalidParameter()); // Only previous Follow IDs allowed to be reused
            require($storage().followers[accountToFollow][followId] == address(0), Errors.AlreadyExists()); // Follow ID is already taken
        }
        $storage().follows[followerAccount][accountToFollow] = Follow({id: followId, timestamp: timestamp});
        $storage().followers[accountToFollow][followId] = followerAccount;
        $storage().followersCount[accountToFollow]++;
        $storage().followingCount[followerAccount]++;
        return followId;
    }

    function _unfollow(address followerAccount, address accountToUnfollow) internal returns (uint256) {
        require(followerAccount != address(0), Errors.InvalidParameter());
        require(accountToUnfollow != address(0), Errors.InvalidParameter());
        uint256 followId = $storage().follows[followerAccount][accountToUnfollow].id;
        require(followId != 0, Errors.NotFollowing()); // Must be following
        $storage().followersCount[accountToUnfollow]--;
        $storage().followingCount[followerAccount]--;
        delete $storage().followers[accountToUnfollow][followId];
        delete $storage().follows[followerAccount][accountToUnfollow];
        return followId;
    }
}
