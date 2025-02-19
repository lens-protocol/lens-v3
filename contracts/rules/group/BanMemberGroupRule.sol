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
import {IGroup} from "contracts/core/interfaces/IGroup.sol";

contract BanMemberGroupRule is IGroupRule, OwnableMetadataBasedRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak lens.permission.BanMember
    uint256 public constant PID__BAN_MEMBER = uint256(0x9d308cac09fdd9a84cb1807d1735d96bcdf3e6b148cee46755a39c858ee0157f);
    /// @custom:keccak lens.permission.UnbanMember
    uint256 public constant PID__UNBAN_MEMBER =
        uint256(0x22ca63d52e89aec5edc4f87f1dec7197ab8f39c6eb711100459646e6634f5b3b);
    /// @custom:keccak lens.permission.AddMember
    uint256 public constant PID__ADD_MEMBER = uint256(0x19ef038b2d9618004143e998c9c636d9796ef58a03b5e2351e9f8d8446b0c2ab);
    /// @custom:keccak lens.permission.RemoveMember
    uint256 public constant PID__REMOVE_MEMBER =
        uint256(0x8c204b72f1086f607fac077224053e94d5f8a69311195889c42430ffa8646e23);

    /// @custom:keccak lens.param.accessControl
    bytes32 public constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;
    /// @custom:keccak lens.param.requirePidOnAddition
    bytes32 public constant PARAM__REQUIRE_PID_ON_ADDITION =
        0xec619bc91af8a6afe5069b6918996ba86f578cb68987c3cb22b170d0038aea48;
    /// @custom:keccak lens.param.requirePidOnRemoval
    bytes32 public constant PARAM__REQUIRE_PID_ON_REMOVAL =
        0x53c5340c2d57e16c0c03b02534173406d6ce5c3a915c083937e0e0a80543d33c;

    /// @custom:keccak lens.param.banMember
    bytes32 public constant PARAM__BAN_MEMBER = 0xc18b1794d154829be8985d985e210a3ff29be11c97069d5a0558da13bdbf2277;

    event Lens_BanMemberGroupRule_MemberBanned(
        address indexed group, bytes32 indexed configSalt, address indexed bannedAccount, address bannedBy
    );
    event Lens_BanMemberGroupRule_MemberUnbanned(
        address indexed group, bytes32 indexed configSalt, address indexed unbannedAccount, address unbannedBy
    );

    struct Configuration {
        address accessControl;
        bool requirePidOnAddition;
        bool requirePidOnRemoval;
    }

    mapping(address group => mapping(bytes32 configSalt => Configuration configuration)) internal _configuration;
    mapping(address group => mapping(bytes32 configSalt => mapping(address account => bool isBanned))) internal _isBanned;

    constructor(address owner, string memory metadataURI) OwnableMetadataBasedRule(owner, metadataURI) {
        emit Events.Lens_PermissionId_Available(PID__BAN_MEMBER, "lens.permission.BanMember");
        emit Events.Lens_PermissionId_Available(PID__UNBAN_MEMBER, "lens.permission.UnbanMember");
        emit Events.Lens_PermissionId_Available(PID__ADD_MEMBER, "lens.permission.AddMember");
        emit Events.Lens_PermissionId_Available(PID__REMOVE_MEMBER, "lens.permission.RemoveMember");
    }

    function ban(bytes32 configSalt, address group, address account) external {
        // Banning without removal is only allowed for non-members.
        require(IGroup(group).isMember(account) == false, Errors.InvalidParameter());
        _configuration[group][configSalt].accessControl.requireAccess(msg.sender, group, PID__BAN_MEMBER);
        _isBanned[group][configSalt][account] = true;
        emit Lens_BanMemberGroupRule_MemberBanned(group, configSalt, account, msg.sender);
    }

    function unban(bytes32 configSalt, address group, address account) external {
        // Unbanning without removal is only allowed for non-members.
        require(IGroup(group).isMember(account) == false, Errors.InvalidParameter());
        _configuration[group][configSalt].accessControl.requireAccess(msg.sender, group, PID__UNBAN_MEMBER);
        _isBanned[group][configSalt][account] = false;
        emit Lens_BanMemberGroupRule_MemberUnbanned(group, configSalt, account, msg.sender);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration = _getDefaultConfigurationValues(configSalt);
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__ACCESS_CONTROL) {
                configuration.accessControl = abi.decode(ruleParams[i].value, (address));
            } else if (ruleParams[i].key == PARAM__REQUIRE_PID_ON_ADDITION) {
                configuration.requirePidOnAddition = abi.decode(ruleParams[i].value, (bool));
            } else if (ruleParams[i].key == PARAM__REQUIRE_PID_ON_REMOVAL) {
                configuration.requirePidOnRemoval = abi.decode(ruleParams[i].value, (bool));
            }
        }
        configuration.accessControl.verifyHasAccessFunction();
        _configuration[msg.sender][configSalt].accessControl = configuration.accessControl;
        _configuration[msg.sender][configSalt].requirePidOnAddition = configuration.requirePidOnAddition;
        _configuration[msg.sender][configSalt].requirePidOnRemoval = configuration.requirePidOnRemoval;
    }

    function processAddition(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        if (_configuration[msg.sender][configSalt].requirePidOnAddition) {
            _configuration[msg.sender][configSalt].accessControl.requireAccess(
                originalMsgSender, msg.sender, PID__ADD_MEMBER
            );
        }
        if (_isBanned[msg.sender][configSalt][account]) {
            for (uint256 i = 0; i < ruleParams.length; i++) {
                if (ruleParams[i].key == PARAM__BAN_MEMBER) {
                    require(!abi.decode(ruleParams[i].value, (bool)), Errors.InvalidParameter()); // Cannot ban while adding to the group.
                    _isBanned[msg.sender][configSalt][account] = false;
                    _configuration[msg.sender][configSalt].accessControl.requireAccess(
                        originalMsgSender, msg.sender, PID__UNBAN_MEMBER
                    );
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
        if (_configuration[msg.sender][configSalt].requirePidOnRemoval) {
            _configuration[msg.sender][configSalt].accessControl.requireAccess(
                originalMsgSender, msg.sender, PID__REMOVE_MEMBER
            );
        }
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__BAN_MEMBER) {
                if (abi.decode(ruleParams[i].value, (bool))) {
                    _isBanned[msg.sender][configSalt][account] = true;
                    _configuration[msg.sender][configSalt].accessControl.requireAccess(
                        originalMsgSender, msg.sender, PID__BAN_MEMBER
                    );
                    emit Lens_BanMemberGroupRule_MemberBanned(msg.sender, configSalt, account, originalMsgSender);
                } else {
                    // Cannot unban while kicking from the group.
                    require(!_isBanned[msg.sender][configSalt][account], Errors.InvalidParameter());
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
        require(!_isBanned[msg.sender][configSalt][account], Errors.Banned());
    }

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function _getDefaultConfigurationValues(bytes32 configSalt) internal view returns (Configuration memory) {
        if (_configuration[msg.sender][configSalt].accessControl == address(0)) {
            // If this is the first time being configured, by default, require PID on addition and removal.
            return Configuration(address(0), true, true);
        } else {
            // However, if it was already configured in the past, use the previous configured values as default values.
            return _configuration[msg.sender][configSalt];
        }
    }
}
