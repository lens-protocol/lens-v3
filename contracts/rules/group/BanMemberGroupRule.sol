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

    event Lens_BanMemberGroupRule_MemberBanned(
        address indexed group, bytes32 indexed configSalt, address indexed bannedAccount, address bannedBy
    );
    event Lens_BanMemberGroupRule_MemberUnbanned(
        address indexed group, bytes32 indexed configSalt, address indexed unbannedAccount, address unbannedBy
    );

    mapping(address => mapping(bytes32 => address)) internal _accessControl;
    mapping(address => mapping(bytes32 => mapping(address => bool))) internal _isMemberBanned;

    constructor() {
        emit Events.Lens_PermissionId_Available(BAN_MEMBER_PID, "BAN_MEMBER");
        emit Events.Lens_PermissionId_Available(UNBAN_MEMBER_PID, "UNBAN_MEMBER");
    }

    function ban(bytes32 configSalt, address group, address account) external {
        _accessControl[group][configSalt].requireAccess(msg.sender, BAN_MEMBER_PID);
        _isMemberBanned[group][configSalt][account] = true;
        emit Lens_BanMemberGroupRule_MemberBanned(group, configSalt, account, msg.sender);
    }

    function unban(bytes32 configSalt, address group, address account) external {
        _accessControl[group][configSalt].requireAccess(msg.sender, UNBAN_MEMBER_PID);
        _isMemberBanned[group][configSalt][account] = false;
        emit Lens_BanMemberGroupRule_MemberUnbanned(group, configSalt, account, msg.sender);
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
        KeyValue[] calldata ruleParams
    ) external override {
        if (_isMemberBanned[msg.sender][configSalt][account]) {
            for (uint256 i = 0; i < ruleParams.length; i++) {
                if (ruleParams[i].key == BAN_MEMBER_PARAM_KEY) {
                    require(!abi.decode(ruleParams[i].value, (bool)));
                    _isMemberBanned[msg.sender][configSalt][account] = false;
                    _accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, UNBAN_MEMBER_PID);
                    emit Lens_BanMemberGroupRule_MemberUnbanned(msg.sender, configSalt, account, originalMsgSender);
                    return;
                }
            }
            // If member is banned and the param to unban was not passed, revert.
            revert();
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
            if (ruleParams[i].key == BAN_MEMBER_PARAM_KEY) {
                if (abi.decode(ruleParams[i].value, (bool))) {
                    _isMemberBanned[msg.sender][configSalt][account] = true;
                    _accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, BAN_MEMBER_PID);
                    emit Lens_BanMemberGroupRule_MemberBanned(msg.sender, configSalt, account, originalMsgSender);
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
        require(!_isMemberBanned[msg.sender][configSalt][account]);
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
