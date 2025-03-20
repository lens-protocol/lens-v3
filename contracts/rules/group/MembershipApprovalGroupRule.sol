// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IRequestBasedGroupRule} from "contracts/core/interfaces/IRequestBasedGroupRule.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract MembershipApprovalGroupRule is OwnableMetadataBasedRule, Initializable, IRequestBasedGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Lens_ApprovalGroupRule_MembershipRequested(
        address indexed group, bytes32 indexed configSalt, address indexed account
    );
    event Lens_ApprovalGroupRule_MembershipRequestCancelled(
        address indexed group, bytes32 indexed configSalt, address indexed account
    );
    event Lens_ApprovalGroupRule_MembershipApproved(
        address indexed group, bytes32 indexed configSalt, address indexed account, address approvedBy
    );
    event Lens_ApprovalGroupRule_MembershipRejected(
        address indexed group, bytes32 indexed configSalt, address indexed account, address rejectedBy
    );

    /// @custom:keccak lens.permission.ApproveMember
    uint256 constant PID__APPROVE_MEMBER = uint256(0x6dee95fe4c317d653a8497c1c8ce08e19bdee16c90d0ec8d1795b29ff85811b6);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;

    /// @custom:keccak lens.storage.MembershipApprovalGroupRule
    bytes32 constant STORAGE__MEMBERSHIP_APPROVAL_GROUP_RULE =
        0x84c95d75b5982bc41a348cb285db156a54787aed88de53b4912c86f03f073b79;

    struct Storage {
        mapping(address group => mapping(bytes32 configSalt => address accessControl)) accessControl;
        mapping(address group => mapping(address account => mapping(bytes32 configSalt => bool requested)))
            isMembershipRequested;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__MEMBERSHIP_APPROVAL_GROUP_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Lens_PermissionId_Available(PID__APPROVE_MEMBER, "lens.permission.ApproveMember");

        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function sendMembershipRequest(bytes32 configSalt, address group, KeyValue[] calldata /* params */ )
        external
        override
    {
        require($storage().isMembershipRequested[group][msg.sender][configSalt] == false, Errors.AlreadyExists());
        $storage().isMembershipRequested[group][msg.sender][configSalt] = true;
        emit Lens_ApprovalGroupRule_MembershipRequested(group, configSalt, msg.sender);
    }

    function cancelMembershipRequest(bytes32 configSalt, address group, KeyValue[] calldata /* params */ )
        external
        override
    {
        require($storage().isMembershipRequested[group][msg.sender][configSalt], Errors.DoesNotExist());
        delete $storage().isMembershipRequested[group][msg.sender][configSalt];
        emit Lens_ApprovalGroupRule_MembershipRequestCancelled(group, configSalt, msg.sender);
    }

    function rejectMembershipRequest(bytes32 configSalt, address group, address account) external {
        $storage().accessControl[group][configSalt].requireAccess(msg.sender, PID__APPROVE_MEMBER);
        _rejectMembershipRequest(configSalt, group, account);
    }

    function rejectMembershipRequests(bytes32 configSalt, address group, address[] calldata accounts) external {
        $storage().accessControl[group][configSalt].requireAccess(msg.sender, PID__APPROVE_MEMBER);
        for (uint256 i = 0; i < accounts.length; i++) {
            _rejectMembershipRequest(configSalt, group, accounts[i]);
        }
    }

    function _rejectMembershipRequest(bytes32 configSalt, address group, address account) internal {
        require($storage().isMembershipRequested[group][account][configSalt], Errors.DoesNotExist());
        delete $storage().isMembershipRequested[group][account][configSalt];
        emit Lens_ApprovalGroupRule_MembershipRejected(group, configSalt, account, msg.sender);
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
        $storage().accessControl[msg.sender][configSalt] = accessControl;
    }

    function processAddition(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require($storage().isMembershipRequested[msg.sender][account][configSalt], Errors.DoesNotExist());
        delete $storage().isMembershipRequested[msg.sender][account][configSalt];
        $storage().accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, PID__APPROVE_MEMBER);
        emit Lens_ApprovalGroupRule_MembershipApproved(msg.sender, configSalt, account, originalMsgSender);
    }

    function processJoining(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
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
