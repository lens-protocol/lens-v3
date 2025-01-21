// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract MembershipApprovalGroupRule is IGroupRule, OwnableMetadataBasedRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak lens.permission.ApproveMember
    uint256 constant PID__APPROVE_MEMBER = uint256(0x6dee95fe4c317d653a8497c1c8ce08e19bdee16c90d0ec8d1795b29ff85811b6);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;

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

    constructor(address owner, string memory metadataURI) OwnableMetadataBasedRule(owner, metadataURI) {
        emit Events.Lens_PermissionId_Available(PID__APPROVE_MEMBER, "lens.permission.ApproveMember");
    }

    function requestMembership(bytes32 configSalt, address group) external {
        require(!_membershipRequests[group][msg.sender][configSalt].isRequested, Errors.AlreadyExists());
        _membershipRequests[group][msg.sender][configSalt].isRequested = true;
        emit Lens_ApprovalGroupRule_MembershipRequested(group, msg.sender);
    }

    function cancelMembershipRequest(bytes32 configSalt, address group) external {
        require(_membershipRequests[group][msg.sender][configSalt].isRequested, Errors.DoesNotExist());
        delete _membershipRequests[group][msg.sender][configSalt];
        emit Lens_ApprovalGroupRule_MembershipRequestCancelled(group, msg.sender);
    }

    function answerMembershipRequest(bytes32 configSalt, address group, address account, bool isApproved) external {
        require(_membershipRequests[group][account][configSalt].isRequested, Errors.DoesNotExist());
        if (isApproved) {
            _membershipRequests[group][account][configSalt].isApproved = isApproved;
            emit Lens_ApprovalGroupRule_MembershipApproved(group, account, msg.sender);
        } else {
            delete _membershipRequests[group][account][configSalt];
            emit Lens_ApprovalGroupRule_MembershipRejected(group, account, msg.sender);
        }
        _accessControl[group][configSalt].requireAccess(msg.sender, PID__APPROVE_MEMBER);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        address accessControl;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__ACCESS_CONTROL) {
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
            _accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, PID__APPROVE_MEMBER);
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
        require(_membershipRequests[msg.sender][account][configSalt].isApproved, Errors.NotAllowed());
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
        revert Errors.NotImplemented();
    }

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }
}
