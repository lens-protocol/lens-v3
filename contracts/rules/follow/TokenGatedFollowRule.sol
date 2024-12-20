// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IFollowRule} from "./../../core/interfaces/IFollowRule.sol";
import {TokenGatedRule} from "./../base/TokenGatedRule.sol";
import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {KeyValue} from "./../../core/types/Types.sol";
import {Events} from "./../../core/types/Events.sol";

contract TokenGatedFollowRule is TokenGatedRule, IFollowRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant SKIP_TOKEN_GATE_PID = uint256(keccak256("SKIP_TOKEN_GATE"));

    // keccak256("lens.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0x6552dd4db64bdb68f2725e4865ecb072df1c2befcfb455b69e2d2b886a8e185e;

    struct Configuration {
        address accessControl;
        TokenGateConfiguration tokenGate;
    }

    mapping(address => mapping(address => mapping(bytes32 => Configuration))) internal _configuration;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_TOKEN_GATE_PID, "SKIP_TOKEN_GATE");
    }

    function configure(bytes32 configSalt, address account, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        configuration.accessControl.verifyHasAccessFunction();
        _validateTokenGateConfiguration(configuration.tokenGate);
        _configuration[msg.sender][account][configSalt] = configuration;
    }

    function processFollow(
        bytes32 configSalt,
        address, /* originalMsgSender */
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(
            _configuration[msg.sender][accountToFollow][configSalt].accessControl,
            _configuration[msg.sender][accountToFollow][configSalt].tokenGate,
            followerAccount
        );
    }

    function _validateTokenBalance(
        address accessControl,
        TokenGateConfiguration memory tokenGateConfiguration,
        address account
    ) internal view {
        if (!accessControl.hasAccess(account, SKIP_TOKEN_GATE_PID)) {
            _validateTokenBalance(tokenGateConfiguration, account);
        }
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == ACCESS_CONTROL_PARAM_KEY) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == TOKEN_GATE_PARAM_KEY) {
                configuration.tokenGate = abi.decode(params[i].value, (TokenGateConfiguration));
            }
        }
        return configuration;
    }
}
