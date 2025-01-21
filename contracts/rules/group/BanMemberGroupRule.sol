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

contract BanMemberGroupRule is IGroupRule, OwnableMetadataBasedRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak lens.permission.BanMember
    uint256 constant PID__BAN_MEMBER = uint256(0x9d308cac09fdd9a84cb1807d1735d96bcdf3e6b148cee46755a39c858ee0157f);
    /// @custom:keccak lens.permission.UnbanMember
    uint256 constant PID__UNBAN_MEMBER = uint256(0x22ca63d52e89aec5edc4f87f1dec7197ab8f39c6eb711100459646e6634f5b3b);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;

    /// @custom:keccak lens.param.banMember
    bytes32 constant PARAM__BAN_MEMBER = 0xc18b1794d154829be8985d985e210a3ff29be11c97069d5a0558da13bdbf2277;

    event Lens_BanMemberGroupRule_MemberBanned(
        address indexed group, bytes32 indexed configSalt, address indexed bannedAccount, address bannedBy
    );
    event Lens_BanMemberGroupRule_MemberUnbanned(
        address indexed group, bytes32 indexed configSalt, address indexed unbannedAccount, address unbannedBy
    );

    mapping(address => mapping(bytes32 => address)) internal _accessControl;
    mapping(address => mapping(bytes32 => mapping(address => bool))) internal _isMemberBanned;

    constructor(address owner, string memory metadataURI) OwnableMetadataBasedRule(owner, metadataURI) {
        emit Events.Lens_PermissionId_Available(PID__BAN_MEMBER, "lens.permission.BanMember");
        emit Events.Lens_PermissionId_Available(PID__UNBAN_MEMBER, "lens.permission.UnbanMember");
    }

    function ban(bytes32 configSalt, address group, address account) external {
        _accessControl[group][configSalt].requireAccess(msg.sender, PID__BAN_MEMBER);
        _isMemberBanned[group][configSalt][account] = true;
        emit Lens_BanMemberGroupRule_MemberBanned(group, configSalt, account, msg.sender);
    }

    function unban(bytes32 configSalt, address group, address account) external {
        _accessControl[group][configSalt].requireAccess(msg.sender, PID__UNBAN_MEMBER);
        _isMemberBanned[group][configSalt][account] = false;
        emit Lens_BanMemberGroupRule_MemberUnbanned(group, configSalt, account, msg.sender);
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
        KeyValue[] calldata ruleParams
    ) external override {
        if (_isMemberBanned[msg.sender][configSalt][account]) {
            for (uint256 i = 0; i < ruleParams.length; i++) {
                if (ruleParams[i].key == PARAM__BAN_MEMBER) {
                    require(!abi.decode(ruleParams[i].value, (bool)), Errors.InvalidParameter()); // Cannot ban while adding to the group.
                    _isMemberBanned[msg.sender][configSalt][account] = false;
                    _accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, PID__UNBAN_MEMBER);
                    emit Lens_BanMemberGroupRule_MemberUnbanned(msg.sender, configSalt, account, originalMsgSender);
                    return;
                }
            }
            // If member is banned and the param to unban was not passed, revert.
            revert Errors.Banned();
        }
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__BAN_MEMBER) {
                if (abi.decode(ruleParams[i].value, (bool))) {
                    _isMemberBanned[msg.sender][configSalt][account] = true;
                    _accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, PID__BAN_MEMBER);
                    emit Lens_BanMemberGroupRule_MemberBanned(msg.sender, configSalt, account, originalMsgSender);
                } else {
                    // Cannot unban while kicking from the group.
                    require(!_isMemberBanned[msg.sender][configSalt][account], Errors.InvalidParameter());
                }
                return;
            }
        }
    }

    function processJoining(
        bytes32 configSalt,
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(!_isMemberBanned[msg.sender][configSalt][account], Errors.Banned());
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
