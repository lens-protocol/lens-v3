// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroupRule} from "./../../core/interfaces/IGroupRule.sol";
import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";
import {KeyValue} from "./../../core/types/Types.sol";

contract MembershipApprovalGroupRule is IGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant APPROVE_MEMBER_PID = uint256(keccak256("APPROVE_MEMBER"));

    // keccak256("lens.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0x6552dd4db64bdb68f2725e4865ecb072df1c2befcfb455b69e2d2b886a8e185e;

    // TODO: Should we add `messageURI` for both the request and the rejection? so you could provide a reason.
    event Lens_ApprovalGroupRule_MembershipRequested(address indexed group, address indexed account);
    event Lens_ApprovalGroupRule_MembershipRequestCancelled(address indexed group, address indexed account);
    event Lens_ApprovalGroupRule_MembershipApproved(address indexed group, address indexed account, address approvedBy);
    event Lens_ApprovalGroupRule_MembershipRejected(address indexed group, address indexed account, address rejectedBy);
    event Lens_ApprovalGroupRule_MembershipGranted(address indexed group, address indexed account);

    struct MembershipRequest {
        bool isRequested;
        bool isApproved;
    }

    mapping(address => mapping(bytes32 => address)) internal _accessControl;
    mapping(address => mapping(address => mapping(bytes32 => MembershipRequest))) internal _membershipRequests;

    constructor() {
        emit Events.Lens_PermissionId_Available(APPROVE_MEMBER_PID, "APPROVE_MEMBER");
    }

    function requestMembership(bytes32 configSalt, address group) external {
        require(!_membershipRequests[group][msg.sender][configSalt].isRequested);
        _membershipRequests[group][msg.sender][configSalt].isRequested = true;
        emit Lens_ApprovalGroupRule_MembershipRequested(group, msg.sender);
    }

    function cancelMembershipRequest(bytes32 configSalt, address group) external {
        require(_membershipRequests[group][msg.sender][configSalt].isRequested);
        delete _membershipRequests[group][msg.sender][configSalt];
        emit Lens_ApprovalGroupRule_MembershipRequestCancelled(group, msg.sender);
    }

    function answerMembershipRequest(bytes32 configSalt, address group, address account, bool isApproved) external {
        require(_membershipRequests[group][account][configSalt].isRequested);
        if (isApproved) {
            _membershipRequests[group][account][configSalt].isApproved = isApproved;
            emit Lens_ApprovalGroupRule_MembershipApproved(group, account, msg.sender);
        } else {
            delete _membershipRequests[group][account][configSalt];
            emit Lens_ApprovalGroupRule_MembershipRejected(group, account, msg.sender);
        }
        require(_accessControl[group][configSalt].hasAccess(msg.sender, APPROVE_MEMBER_PID));
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        address accessControl;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == ACCESS_CONTROL_PARAM_KEY) {
                accessControl = abi.decode(ruleParams[i].value, (address));
                break;
            }
        }
        accessControl.verifyHasAccessFunction();
        _accessControl[msg.sender][configSalt] = accessControl;
    }

    function processAddition(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        if (!_membershipRequests[msg.sender][account][configSalt].isApproved) {
            require(_accessControl[msg.sender][configSalt].hasAccess(originalMsgSender, APPROVE_MEMBER_PID));
            emit Lens_ApprovalGroupRule_MembershipApproved(msg.sender, account, originalMsgSender);
        }
        delete _membershipRequests[msg.sender][account][configSalt];
        emit Lens_ApprovalGroupRule_MembershipGranted(msg.sender, account);
    }

    function processJoining(
        bytes32 configSalt,
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require(_membershipRequests[msg.sender][account][configSalt].isApproved);
        delete _membershipRequests[msg.sender][account][configSalt];
        emit Lens_ApprovalGroupRule_MembershipGranted(msg.sender, account);
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert();
    }

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert();
    }
}
