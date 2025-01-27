// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Membership} from "contracts/core/interfaces/IGroup.sol";
import {Errors} from "contracts/core/types/Errors.sol";

library GroupCore {
    // Storage

    struct Storage {
        uint256 lastMemberIdAssigned;
        uint256 numberOfMembers;
        mapping(address => Membership) memberships;
    }

    /// @custom:keccak lens.storage.GroupCore
    bytes32 constant STORAGE__GROUP_CORE = 0x21ab408a492cf8beda2879363dd3a4ec8ba15c85532aa540e0e12415acdd09ed;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__GROUP_CORE
        }
    }

    // Internal functions - Use these functions to be called as an inlined library

    function _isMember(address account) internal view returns (bool) {
        return $storage().memberships[account].id != 0;
    }

    function _getMembership(address account) internal view returns (Membership memory) {
        return $storage().memberships[account];
    }

    function _grantMembership(address account) internal returns (uint256) {
        require(account != address(0), Errors.InvalidParameter());
        uint256 membershipId = ++$storage().lastMemberIdAssigned;
        $storage().numberOfMembers++;
        require($storage().memberships[account].id == 0, Errors.RedundantStateChange()); // Must not be a member yet
        $storage().memberships[account] = Membership(membershipId, block.timestamp);
        return membershipId;
    }

    function _revokeMembership(address account) internal returns (uint256) {
        require(account != address(0), Errors.InvalidParameter());
        uint256 membershipId = $storage().memberships[account].id;
        require(membershipId != 0, Errors.RedundantStateChange()); // Must be a member
        $storage().numberOfMembers--;
        delete $storage().memberships[account];
        return membershipId;
    }
}
