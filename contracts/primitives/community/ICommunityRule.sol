// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICommunityRule {
    function configure(bytes calldata data) external;

    function processJoining(address account, uint256 membershipId, bytes calldata data) external;

    function processRemoval(address account, uint256 membershipId, bytes calldata data) external;

    function processLeaving(address account, uint256 membershipId, bytes calldata data) external;
}
