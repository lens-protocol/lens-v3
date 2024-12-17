// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {IUsernameRule} from "./../../core/interfaces/IUsernameRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";
import {KeyValue} from "./../../core/types/Types.sol";

contract ReservedUsernameRule is IUsernameRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    // uint256(keccak256("CREATE_RESERVED_USERNAME"))
    uint256 immutable CREATE_RESERVED_USERNAME_PID =
        uint256(0xfb95904fa3067a919177cb314539246e6f76089564454716cce76492e210edfc);

    // keccak256("lens.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0x6552dd4db64bdb68f2725e4865ecb072df1c2befcfb455b69e2d2b886a8e185e;
    // keccak256("lens.rules.username.CharsetUsernameRule.param.key.CharsetRestrictions.allowNumeric");
    bytes32 immutable ALLOW_NUMERIC_PARAM_KEY = 0x99d79d7e6786d3f6700df19cf91a74d5ed8a7432315a6bd2c8e4b2f31d3ac48a;
    // keccak256("lens.rules.username.CharsetUsernameRule.param.key.CharsetRestrictions.allowLatinLowercase");

    mapping(address => mapping(bytes4 => mapping(bytes32 => Configuration))) internal _configuration;

    mapping(address => mapping(bytes32 => mapping(string => bool))) internal _isUsernameReserved;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_CHARSET_PID, "SKIP_CHARSET");
    }

    function configure(
        bytes4 ruleSelector,
        bytes32 salt,
        KeyValue[] calldata ruleConfigurationParams
    ) external override {
        require(ruleSelector == this.processCreation.selector);
        Configuration memory configuration = _extractConfigurationFromParams(ruleConfigurationParams);
        configuration.accessControl.verifyHasAccessFunction();
        _configuration[msg.sender][ruleSelector][salt] = configuration;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external view override {
        Configuration memory configuration = _configuration[msg.sender][this.processCreation.selector][configSalt];
        if (!configuration.accessControl.hasAccess(originalMsgSender, SKIP_CHARSET_PID)) {
            _processRestrictions(username, configuration.charsetRestrictions);
        }
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override {
        revert();
    }

    function processAssigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override {
        revert();
    }

    function processUnassigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override {
        revert();
    }
}
