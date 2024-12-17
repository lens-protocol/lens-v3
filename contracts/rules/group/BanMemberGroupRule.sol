// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroupRule} from "./../../core/interfaces/IGroupRule.sol";
import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";
import {KeyValue} from "./../../core/types/Types.sol";

contract BanMemberGroupRule is IGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant BAN_MEMBER_PID = uint256(keccak256("BAN_MEMBER"));
    uint256 constant UNBAN_MEMBER_PID = uint256(keccak256("UNBAN_MEMBER"));

    // keccak256("lens.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0x6552dd4db64bdb68f2725e4865ecb072df1c2befcfb455b69e2d2b886a8e185e;
    // keccak256("lens.param.key.banMember");
    bytes32 immutable BAN_MEMBER_PARAM_KEY = 0xbb2ac1c157eaec4f8d53724664c35e575e75b44cc292e3d6dc6ff5c60a2b36a1;

    event Lens_BanMemberGroupRule_MemberBanned(address indexed group, address indexed account);
    event Lens_BanMemberGroupRule_MemberUnbanned(address indexed group, address indexed account);

    struct Storage {
        address accessControl;
        mapping(address => bool) isMemberBanned;
        mapping(bytes4 => bool) someShitBySelector;
    }

    // mapping(address => mapping(bytes4 => mapping(bytes32 => address))) internal _accessControl;
    // mapping(address => mapping(bytes32 => mapping(address => bool))) internal _isMemberBanned;

    mapping(address => mapping(bytes32 => Storage)) internal _storage;

    constructor() {
        emit Events.Lens_PermissionId_Available(BAN_MEMBER_PID, "BAN_MEMBER");
        emit Events.Lens_PermissionId_Available(UNBAN_MEMBER_PID, "UNBAN_MEMBER");
    }

    function ban(bytes32 configSalt, address group, address account) external {
        _accessControl[group][configSalt].requireAccess(msg.sender, BAN_MEMBER_PID);
        _isMemberBanned[group][configSalt][account] = true;
        emit Lens_BanMemberGroupRule_MemberBanned(group, account);
    }

    function unban(bytes32 configSalt, address group, address account) external {
        _accessControl[group][configSalt].requireAccess(msg.sender, UNBAN_MEMBER_PID);
        _isMemberBanned[group][configSalt][account] = false;
        emit Lens_BanMemberGroupRule_MemberUnbanned(group, account);
    }

    function configure(
        bytes4 ruleSelector, // = IGroupRule.processAddition.selector
        bytes32 salt, // = 0xC0FFEE
        KeyValue[] calldata ruleConfigurationParams
    ) external override {
        _validateSelector(ruleSelector);
        address accessControl;
        for (uint256 i = 0; i < ruleConfigurationParams.length; i++) {
            if (ruleConfigurationParams[i].key == ACCESS_CONTROL_PARAM_KEY) {
                accessControl = abi.decode(ruleConfigurationParams[i].value, (address));
                break;
            }
        }
        accessControl.verifyHasAccessFunction();
        _accessControl[msg.sender][ruleSelector][salt] = accessControl;
    }

    function processAddition(
        bytes32 configSalt,
        address, /* originalMsgSender */
        address account,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external override {
        require(!_isMemberBanned[msg.sender][configSalt][account]);
    }

    function processJoining(
        bytes32 configSalt,
        address account,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external override {
        require(!_isMemberBanned[msg.sender][configSalt][account]);
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata ruleExecutionParams
    ) external pure override {
        for (uint256 i = 0; i < ruleExecutionParams.length; i++) {
            if (ruleExecutionParams[i].key == BAN_MEMBER_PARAM_KEY) {
                if (abi.decode(ruleExecutionParams[i].value, (bool))) {
                    _isMemberBanned[msg.sender][configSalt][account] = true;
                    _accessControl[msg.sender][this.processRemoval.selector][configSalt].requireAccess(
                        originalMsgSender, BAN_MEMBER_PID
                    );
                    emit Lens_BanMemberGroupRule_MemberBanned(msg.sender, account);
                }
                return;
            }
        }
    }

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override {
        revert();
    }

    function _validateSelector(bytes4 ruleSelector) internal pure {
        require(
            ruleSelector == this.processAddition.selector || ruleSelector == this.processJoining.selector
                || ruleSelector == this.processRemoval.selector
        );
    }
}
