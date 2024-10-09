// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../libraries/ExtraDataLib.sol";

library CommunityCore {
    using ExtraDataLib for mapping(bytes32 => bytes);

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
        mapping(bytes32 => bytes) extraData;
    }

    // keccak256('lens.community.core.storage')
    bytes32 constant CORE_STORAGE_SLOT = 0xe3d84445237a06d082986111e0d101bb8001f44a5807dc25d1929b8fc52c1c69;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := CORE_STORAGE_SLOT
        }
    }

    // External functions - Use these functions to be called through DELEGATECALL

    function grantMembership(address account) external returns (uint256) {
        return _grantMembership(account);
    }

    function revokeMembership(address account) external returns (uint256) {
        return _revokeMembership(account);
    }

    function setExtraData(DataElement[] calldata extraDataToSet) external {
        $storage().extraData.set(extraDataToSet);
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

    function _setExtraData(DataElement[] calldata extraDataToSet) internal {
        $storage().extraData.set(extraDataToSet);
    }
}
