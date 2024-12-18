// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

library GroupCore {
    struct Membership {
        uint256 id;
        uint256 timestamp;
    }

    // Storage

    struct Storage {
        string metadataURI;
        uint256 lastMemberIdAssigned;
        uint256 numberOfMembers;
        mapping(address => Membership) memberships;
    }

    // keccak256('lens.group.core.storage')
    bytes32 constant CORE_STORAGE_SLOT = 0xe3d84445237a06d082986111e0d101bb8001f44a5807dc25d1929b8fc52c1c69;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := CORE_STORAGE_SLOT
        }
    }

    // Internal functions - Use these functions to be called as an inlined library

    function _grantMembership(address account) internal returns (uint256) {
        uint256 membershipId = ++$storage().lastMemberIdAssigned;
        $storage().numberOfMembers++;
        require($storage().memberships[account].id == 0); // Must not be a member yet
        $storage().memberships[account] = Membership(membershipId, block.timestamp);
        return membershipId;
    }

    function _revokeMembership(address account) internal returns (uint256) {
        uint256 membershipId = $storage().memberships[account].id;
        require(membershipId != 0); // Must be a member
        $storage().numberOfMembers--;
        delete $storage().memberships[account];
        return membershipId;
    }
}
