// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {IUsernameRule} from "./../../core/interfaces/IUsernameRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";
import {KeyValue} from "./../../core/types/Types.sol";

contract LengthUsernameRule is IUsernameRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant SKIP_MIN_LENGTH_PID = uint256(keccak256("SKIP_MIN_LENGTH"));
    uint256 constant SKIP_MAX_LENGTH_PID = uint256(keccak256("SKIP_MAX_LENGTH"));

    // keccak256("lens.rules.username.LengthUsernameRule.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0xcb74f3bf68b3b8b4e8d9acc2031cb2cea7104460cf027809e2d557241970cf2f;
    // keccak256("lens.rules.username.LengthUsernameRule.param.key.LengthRestrictions.min");
    bytes32 immutable MIN_LENGTH_PARAM_KEY = 0x422f1cf00b1079acacf4b218aeed45c02143aca53f622b7ab03d6960ab052fc3;
    // keccak256("lens.rules.username.LengthUsernameRule.param.key.LengthRestrictions.max");
    bytes32 immutable MAX_LENGTH_PARAM_KEY = 0x07014494232a11e71c003affb5e107b669a9b2b4c523a50097f41c6b95916081;

    struct LengthRestrictions {
        uint8 min;
        uint8 max;
    }

    struct Configuration {
        address accessControl;
        LengthRestrictions lengthRestrictions;
    }

    mapping(address => mapping(bytes32 => Configuration)) internal _configuration;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_MIN_LENGTH_PID, "SKIP_MIN_LENGTH");
        emit Events.Lens_PermissionId_Available(SKIP_MAX_LENGTH_PID, "SKIP_MAX_LENGTH");
    }

    function configure(
        bytes4 ruleSelector,
        bytes32 salt,
        KeyValue[] calldata ruleConfigurationParams
    ) external override {
        require(ruleSelector == this.processCreation.selector);
        Configuration memory configuration = _extractConfigurationFromParams(ruleConfigurationParams);
        configuration.accessControl.verifyHasAccessFunction();
        require(
            configuration.lengthRestrictions.max == 0
                || configuration.lengthRestrictions.min <= configuration.lengthRestrictions.max
        ); // Min length cannot be greater than max length
        _configuration[msg.sender][salt] = configuration;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external view override returns (bool) {
        Configuration memory configuration = _configuration[msg.sender][configSalt];
        uint256 usernameLength = bytes(username).length;
        if (
            configuration.lengthRestrictions.min != 0
                && !configuration.accessControl.hasAccess(originalMsgSender, SKIP_MIN_LENGTH_PID)
        ) {
            require(usernameLength >= configuration.lengthRestrictions.min, "Username: too short");
        }
        if (
            configuration.lengthRestrictions.max != 0
                && !configuration.accessControl.hasAccess(originalMsgSender, SKIP_MAX_LENGTH_PID)
        ) {
            require(usernameLength <= configuration.lengthRestrictions.max, "Username: too long");
        }
        return true;
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override returns (bool) {
        return false;
    }

    function processAssigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override returns (bool) {
        return false;
    }

    function processUnassigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override returns (bool) {
        return false;
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == ACCESS_CONTROL_PARAM_KEY) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == MIN_LENGTH_PARAM_KEY) {
                configuration.lengthRestrictions.min = abi.decode(params[i].value, (uint8));
            } else if (params[i].key == MAX_LENGTH_PARAM_KEY) {
                configuration.lengthRestrictions.max = abi.decode(params[i].value, (uint8));
            }
        }
        return configuration;
    }
}
