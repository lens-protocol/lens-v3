// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Follow} from "./IGraph.sol";
import "../libraries/ExtraDataLib.sol";

library GraphCore {
    using ExtraDataLib for mapping(bytes32 => bytes);

    // Storage

    struct Storage {
        string metadataURI;
        mapping(address => uint256) lastFollowIdAssigned;
        mapping(address => mapping(address => Follow)) follows;
        mapping(address => mapping(uint256 => address)) followers;
        mapping(address => uint256) followersCount;
        mapping(bytes32 => bytes) extraData;
    }

    // keccak256('lens.graph.core.storage')
    bytes32 constant CORE_STORAGE_SLOT = 0x29a85df5a038cd27b30b628cc380bae0d47a34cf0abae91c50f7411863dd209b;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := CORE_STORAGE_SLOT
        }
    }

    // External functions - Use these functions to be called through DELEGATECALL

    function follow(address followerAccount, address accountToFollow, uint256 followId) external returns (uint256) {
        return _follow(followerAccount, accountToFollow, followId);
    }

    function unfollow(address followerAccount, address accountToUnfollow) external returns (uint256) {
        return _unfollow(followerAccount, accountToUnfollow);
    }

    function setExtraData(DataElement[] calldata extraDataToSet) external {
        $storage().extraData.set(extraDataToSet);
    }

    // Internal functions - Use these functions to be called as an inlined library

    function _follow(address followerAccount, address accountToFollow, uint256 followId) internal returns (uint256) {
        if (followId == 0) {
            followId = ++$storage().lastFollowIdAssigned[accountToFollow];
        } else {
            require(followId < $storage().lastFollowIdAssigned[accountToFollow]); // Only previous Follow IDs allowed to be reused
            require($storage().followers[accountToFollow][followId] == address(0)); // Follow ID is already taken
        }
        $storage().follows[followerAccount][accountToFollow] = Follow({id: followId, timestamp: block.timestamp});
        $storage().followers[accountToFollow][followId] = followerAccount;
        $storage().followersCount[accountToFollow]++;
        return followId;
    }

    function _unfollow(address followerAccount, address accountToUnfollow) internal returns (uint256) {
        uint256 followId = $storage().follows[followerAccount][accountToUnfollow].id;
        require(followId != 0); // Must be following
        $storage().followersCount[accountToUnfollow]--;
        delete $storage().followers[accountToUnfollow][followId];
        delete $storage().follows[followerAccount][accountToUnfollow];
        return followId;
    }

    function _setExtraData(DataElement[] calldata extraDataToSet) internal {
        $storage().extraData.set(extraDataToSet);
    }
}
