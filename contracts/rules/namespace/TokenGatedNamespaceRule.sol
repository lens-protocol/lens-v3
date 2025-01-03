// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {INamespaceRule} from "./../../core/interfaces/INamespaceRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";
import {TokenGatedRule} from "./../base/TokenGatedRule.sol";
import {KeyValue} from "./../../core/types/Types.sol";

contract TokenGatedNamespaceRule is TokenGatedRule, INamespaceRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak lens.permission.SkipTokenGate
    uint256 constant PID__SKIP_TOKEN_GATE = uint256(0x42073514d6ebc3c4c46bdc33d53105f5c563a0d184e86952704eb3e7b74ec1ae);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;

    struct Configuration {
        address accessControl;
        TokenGateConfiguration tokenGate;
    }

    mapping(address => mapping(bytes32 => Configuration)) internal _configuration;

    constructor(string memory metadataURI) TokenGatedRule(metadataURI) {
        emit Events.Lens_PermissionId_Available(PID__SKIP_TOKEN_GATE, "lens.permission.SkipTokenGate");
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        configuration.accessControl.verifyHasAccessFunction();
        _validateTokenGateConfiguration(configuration.tokenGate);
        _configuration[msg.sender][configSalt] = configuration;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].tokenGate,
            originalMsgSender
        );
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].tokenGate,
            originalMsgSender
        );
    }

    function processAssigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].tokenGate,
            originalMsgSender
        );
    }

    function processUnassigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].tokenGate,
            originalMsgSender
        );
    }

    function _validateTokenBalance(
        address accessControl,
        TokenGateConfiguration memory tokenGateConfiguration,
        address account
    ) internal view {
        if (!accessControl.hasAccess(account, PID__SKIP_TOKEN_GATE)) {
            _validateTokenBalance(tokenGateConfiguration, account);
        }
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__TOKEN_GATE) {
                configuration.tokenGate = abi.decode(params[i].value, (TokenGateConfiguration));
            }
        }
        return configuration;
    }
}
