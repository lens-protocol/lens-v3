// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGraphRule} from "contracts/core/interfaces/IGraphRule.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {KeyValue, RuleChange} from "contracts/core/types/Types.sol";
import {Events} from "contracts/core/types/Events.sol";
import {IGroup} from "contracts/core/interfaces/IGroup.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";

contract GroupGatedGraphRule is IGraphRule, MetadataBased {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Lens_Rule_MetadataURISet(string metadataURI);

    /// @custom:keccak lens.permission.SkipTokenGate
    uint256 constant PID__SKIP_TOKEN_GATE = uint256(0x42073514d6ebc3c4c46bdc33d53105f5c563a0d184e86952704eb3e7b74ec1ae);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;
    /// @custom:keccak lens.param.group
    bytes32 constant PARAM__GROUP = 0xa92ea569d1a9f915f96759ba7cea5f135d011c442b0508dbef76a309e55f4458;

    struct Configuration {
        address accessControl;
        address groupGate;
    }

    mapping(address => mapping(bytes32 => Configuration)) internal _configuration;

    constructor(string memory metadataURI) {
        _setMetadataURI(metadataURI);
        emit Events.Lens_PermissionId_Available(PID__SKIP_TOKEN_GATE, "lens.permission.SkipTokenGate");
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Rule_MetadataURISet(metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        configuration.accessControl.verifyHasAccessFunction();
        IGroup(configuration.groupGate).isMember(address(this)); // Aims to verify the provided address is a valid group
        _configuration[msg.sender][configSalt] = configuration;
    }

    function processFollow(
        bytes32 configSalt,
        address, /* originalMsgSender */
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        /**
         * Both ends of the follow connection must comply with the group-gate restriction, then the graph is purely
         * conformed by group members.
         */
        _validateGroupMembership(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].groupGate,
            followerAccount
        );
        _validateGroupMembership(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].groupGate,
            accountToFollow
        );
    }

    function processUnfollow(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* followerAccount */
        address, /* accountToUnfollow */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert();
    }

    function processFollowRuleChanges(
        bytes32, /* configSalt */
        address, /* account */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert();
    }

    function _validateGroupMembership(address accessControl, address group, address account) internal view {
        if (!accessControl.hasAccess(account, PID__SKIP_TOKEN_GATE)) {
            require(IGroup(group).isMember(account), "NotAMember()");
        }
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__GROUP) {
                configuration.groupGate = abi.decode(params[i].value, (address));
            }
        }
        return configuration;
    }
}
