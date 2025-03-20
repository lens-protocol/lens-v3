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
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract AdditionRemovalPidGroupRule is OwnableMetadataBasedRule, Initializable, IGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak lens.param.accessControl
    bytes32 public constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;

    /// @custom:keccak lens.permission.AddMember
    uint256 constant PID__ADD_MEMBER = uint256(0x19ef038b2d9618004143e998c9c636d9796ef58a03b5e2351e9f8d8446b0c2ab);
    /// @custom:keccak lens.permission.RemoveMember
    uint256 constant PID__REMOVE_MEMBER = uint256(0x8c204b72f1086f607fac077224053e94d5f8a69311195889c42430ffa8646e23);

    /// @custom:keccak lens.storage.AdditionRemovalPidGroupRule
    bytes32 constant STORAGE__ADDITION_REMOVAL_PID_GROUP_RULE =
        0x875e2cb3a840696bfd4b902a7075335bfafa204e802c28025d62922181ad12b2;

    struct Storage {
        mapping(address group => mapping(bytes32 configSalt => address accessControl)) accessControl;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__ADDITION_REMOVAL_PID_GROUP_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Lens_PermissionId_Available(PID__ADD_MEMBER, "lens.permission.AddMember");
        emit Events.Lens_PermissionId_Available(PID__REMOVE_MEMBER, "lens.permission.RemoveMember");
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
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
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        $storage().accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, msg.sender, PID__ADD_MEMBER);
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        $storage().accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, msg.sender, PID__REMOVE_MEMBER);
    }

    function processJoining(
        bytes32, /* configSalt */
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
