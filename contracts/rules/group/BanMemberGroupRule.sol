// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IGroup} from "contracts/core/interfaces/IGroup.sol";
import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {KeyValue, RuleProcessingParams} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract BanMemberGroupRule is OwnableMetadataBasedRule, Initializable, IGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Lens_BanMemberGroupRule_MemberBanned(address indexed group, address indexed bannedAccount, address bannedBy);
    event Lens_BanMemberGroupRule_MemberUnbanned(
        address indexed group, address indexed unbannedAccount, address unbannedBy
    );

    /// @custom:keccak lens.permission.BanMember
    uint256 public constant PID__BAN_MEMBER = uint256(0x9d308cac09fdd9a84cb1807d1735d96bcdf3e6b148cee46755a39c858ee0157f);
    /// @custom:keccak lens.permission.UnbanMember
    uint256 public constant PID__UNBAN_MEMBER =
        uint256(0x22ca63d52e89aec5edc4f87f1dec7197ab8f39c6eb711100459646e6634f5b3b);

    /// @custom:keccak lens.param.accessControl
    bytes32 public constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;
    /// @custom:keccak lens.param.banMember
    bytes32 public constant PARAM__BAN_MEMBER = 0xc18b1794d154829be8985d985e210a3ff29be11c97069d5a0558da13bdbf2277;

    /// @custom:keccak lens.storage.BanMemberGroupRule
    bytes32 constant STORAGE__BAN_MEMBER_GROUP_RULE = 0xfc8259e2136310e755e652fc047e16f4f64316c44ed3d7415b132e658362671a;

    struct Storage {
        mapping(address group => address accessControl) groupAccessControl;
        mapping(address group => mapping(address account => bool isBanned)) isMemberBanned;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__BAN_MEMBER_GROUP_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Lens_PermissionId_Available(PID__BAN_MEMBER, "lens.permission.BanMember");
        emit Events.Lens_PermissionId_Available(PID__UNBAN_MEMBER, "lens.permission.UnbanMember");
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function ban(
        address group,
        address account,
        KeyValue[] calldata groupParams,
        RuleProcessingParams[] calldata groupRuleProcessingParams
    ) external {
        $storage().groupAccessControl[group].requireAccess(msg.sender, group, PID__BAN_MEMBER);
        _ban(group, account, msg.sender);
        if (IGroup(group).isMember(account)) {
            IGroup(group).removeMember(account, groupParams, groupRuleProcessingParams);
        }
    }

    function unban(address group, address account) external {
        $storage().groupAccessControl[group].requireAccess(msg.sender, group, PID__UNBAN_MEMBER);
        _unban(group, account, msg.sender);
    }

    struct MemberBatchParams {
        address account;
        KeyValue[] customParams;
        RuleProcessingParams[] ruleProcessingParams;
    }

    function ban(address group, MemberBatchParams[] calldata membersToBan) external {
        $storage().groupAccessControl[group].requireAccess(msg.sender, group, PID__BAN_MEMBER);
        for (uint256 i = 0; i < membersToBan.length; i++) {
            _ban(group, membersToBan[i].account, msg.sender);
            if (IGroup(group).isMember(membersToBan[i].account)) {
                IGroup(group).removeMember(
                    membersToBan[i].account, membersToBan[i].customParams, membersToBan[i].ruleProcessingParams
                );
            }
        }
    }

    function unban(address group, address[] calldata accounts) external {
        $storage().groupAccessControl[group].requireAccess(msg.sender, group, PID__UNBAN_MEMBER);
        for (uint256 i = 0; i < accounts.length; i++) {
            _unban(group, accounts[i], msg.sender);
        }
    }

    function isMemberBanned(address group, address account) external view returns (bool) {
        return $storage().isMemberBanned[group][account];
    }

    /**
     * If multiple instances of this rule are configured for the same group (which is a bad practice),
     * only the last configuration will be applied (as it will override the previous ones).
     */
    function configure(bytes32, /* configSalt */ KeyValue[] calldata ruleParams) external override {
        address accessControl;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__ACCESS_CONTROL) {
                accessControl = abi.decode(ruleParams[i].value, (address));
                break;
            }
        }
        accessControl.verifyHasAccessFunction();
        $storage().groupAccessControl[msg.sender] = accessControl;
    }

    function processAddition(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _requireNotBanned({group: msg.sender, account: account});
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

    function processJoining(
        bytes32, /* configSalt */
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _requireNotBanned({group: msg.sender, account: account});
    }

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function _unban(address group, address account, address unbannedBy) internal {
        $storage().isMemberBanned[group][account] = false;
        emit Lens_BanMemberGroupRule_MemberUnbanned(group, account, unbannedBy);
    }

    function _ban(address group, address account, address bannedBy) internal {
        $storage().isMemberBanned[group][account] = true;
        emit Lens_BanMemberGroupRule_MemberBanned(group, account, bannedBy);
    }

    function _requireNotBanned(address group, address account) internal view {
        require($storage().isMemberBanned[group][account] == false, Errors.Banned());
    }
}
