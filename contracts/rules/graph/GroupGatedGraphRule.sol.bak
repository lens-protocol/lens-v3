// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGraphRule} from "./../../core/interfaces/IGraphRule.sol";
import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {KeyValue, RuleChange} from "./../../core/types/Types.sol";
import {Events} from "./../../core/types/Events.sol";
import {IGroup} from "./../../core/interfaces/IGroup.sol";

contract GroupGatedGraphRule is IGraphRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant SKIP_TOKEN_GATE_PID = uint256(keccak256("SKIP_TOKEN_GATE"));

    // keccak256("lens.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0x6552dd4db64bdb68f2725e4865ecb072df1c2befcfb455b69e2d2b886a8e185e;
    // keccak256("lens.param.key.group");
    bytes32 immutable GROUP_PARAM_KEY = 0xe556a4384e8a110aab4ea745eff2c09de81f87f56e4ecba2205982230d3bd4f4;

    struct Configuration {
        address accessControl;
        address groupGate;
    }

    mapping(address => mapping(bytes4 => mapping(bytes32 => Configuration))) internal _configuration;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_TOKEN_GATE_PID, "SKIP_TOKEN_GATE");
    }

    function configure(bytes4 ruleSelector, bytes32 salt, KeyValue[] calldata ruleConfigurationParams) external {
        _validateSelector(ruleSelector);
        Configuration memory configuration = _extractConfigurationFromParams(ruleConfigurationParams);
        configuration.accessControl.verifyHasAccessFunction();
        IGroup(configuration.groupGate).getMembershipId(address(this));
        _configuration[msg.sender][ruleSelector][salt] = configuration;
    }

    function processFollow(
        bytes32 configSalt,
        address, /* originalMsgSender */
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external view override {
        /**
         * Both ends of the follow connection must comply with the group-gate restriction, then the graph is purely
         * conformed by group members.
         */
        _validateGroupMembership(
            _configuration[msg.sender][this.processFollow.selector][configSalt].accessControl,
            _configuration[msg.sender][this.processFollow.selector][configSalt].groupGate,
            followerAccount
        );
        _validateGroupMembership(
            _configuration[msg.sender][this.processFollow.selector][configSalt].accessControl,
            _configuration[msg.sender][this.processFollow.selector][configSalt].groupGate,
            accountToFollow
        );
    }

    function processUnfollow(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* followerAccount */
        address, /* accountToUnfollow */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override {
        revert();
    }

    function processFollowRuleChanges(
        bytes32, /* configSalt */
        address, /* account */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override {
        revert();
    }

    function _validateGroupMembership(address accessControl, address group, address account) internal view {
        if (!accessControl.hasAccess(account, SKIP_TOKEN_GATE_PID)) {
            require(IGroup(group).getMembershipId(account) != 0, "NotAMember()");
        }
    }

    function _validateSelector(bytes4 ruleSelector) internal pure {
        require(ruleSelector == this.processFollow.selector);
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == ACCESS_CONTROL_PARAM_KEY) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == GROUP_PARAM_KEY) {
                configuration.groupGate = abi.decode(params[i].value, (address));
            }
        }
        return configuration;
    }
}
