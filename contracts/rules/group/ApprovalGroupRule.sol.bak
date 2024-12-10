// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroupRule} from "./../../core/interfaces/IGroupRule.sol";
import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";

contract ApprovalGroupRule is IGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant APPROVE_MEMBER_PID = uint256(keccak256("APPROVE_MEMBER"));

    // TODO: Should we add `messageURI` for both the request and the rejection? so you could provide a reason.
    event Lens_ApprovalGroupRule_MembershipRequested(address indexed group, address indexed account);
    event Lens_ApprovalGroupRule_MembershipApproved(address indexed group, address indexed account);
    event Lens_ApprovalGroupRule_MembershipRejected(address indexed group, address indexed account);
    event Lens_ApprovalGroupRule_MembershipGranted(address indexed group, address indexed account);

    struct MembershipRequest {
        bool isRequested;
        bool isApproved;
    }

    mapping(address => mapping(address => MembershipRequest)) internal _membershipRequests;
    mapping(address => address) internal _accessControl;

    constructor() {
        emit Events.Lens_PermissionId_Available(APPROVE_MEMBER_PID, "APPROVE_MEMBER");
    }

    function configure(bytes calldata data) external {
        address accessControl = abi.decode(data, (address));
        accessControl.verifyHasAccessFunction();
        _accessControl[msg.sender] = accessControl;
    }

    function processJoining(address account, bytes calldata /* data */ ) external returns (bool) {
        require(_membershipRequests[msg.sender][account].isApproved);
        delete _membershipRequests[msg.sender][account];
        emit Lens_ApprovalGroupRule_MembershipGranted(msg.sender, account);
        return true;
    }

    function requestMembership(address group) external {
        require(!_membershipRequests[group][msg.sender].isRequested);
        _membershipRequests[group][msg.sender].isRequested = true;
        emit Lens_ApprovalGroupRule_MembershipRequested(group, msg.sender);
    }

    function answerMembershipRequest(address group, address account, bool isApproved) external {
        _membershipRequests[group][account].isApproved = isApproved;
        require(_accessControl[group].hasAccess(msg.sender, APPROVE_MEMBER_PID));
        if (isApproved) {
            emit Lens_ApprovalGroupRule_MembershipApproved(group, account);
        } else {
            emit Lens_ApprovalGroupRule_MembershipRejected(group, account);
        }
    }

    function processRemoval(address, /* account */ bytes calldata /*data*/ ) external pure returns (bool) {
        return false;
    }
}
