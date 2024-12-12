// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {IUsernameRule} from "./../../core/interfaces/IUsernameRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";
import {SimplePaymentRule} from "./../base/SimplePaymentRule.sol";
import {KeyValue} from "./../../core/types/Types.sol";

contract SimplePaymentUsernameRule is SimplePaymentRule, IUsernameRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant SKIP_PAYMENT_PID = uint256(keccak256("SKIP_PAYMENT"));

    // keccak256("lens.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0x6552dd4db64bdb68f2725e4865ecb072df1c2befcfb455b69e2d2b886a8e185e;

    struct Configuration {
        address accessControl;
        PaymentConfiguration paymentConfiguration;
    }

    mapping(address => mapping(bytes4 => mapping(bytes32 => Configuration))) internal _configuration;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_PAYMENT_PID, "SKIP_PAYMENT");
    }

    function configure(bytes4 ruleSelector, bytes32 salt, KeyValue[] calldata ruleConfigurationParams) external {
        _validateSelector(ruleSelector);
        Configuration memory configuration = _extractConfigurationFromParams(ruleConfigurationParams);
        configuration.accessControl.verifyHasAccessFunction();
        _validatePaymentConfiguration(configuration.paymentConfiguration);
        _configuration[msg.sender][ruleSelector][salt] = configuration;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata ruleExecutionParams
    ) external returns (bool) {
        return _processPayment(
            _configuration[msg.sender][this.processCreation.selector][configSalt].accessControl,
            _configuration[msg.sender][this.processCreation.selector][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleExecutionParams),
            originalMsgSender
        );
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata ruleExecutionParams
    ) external returns (bool) {
        return _processPayment(
            _configuration[msg.sender][this.processRemoval.selector][configSalt].accessControl,
            _configuration[msg.sender][this.processRemoval.selector][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleExecutionParams),
            originalMsgSender
        );
    }

    function processAssigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata ruleExecutionParams
    ) external returns (bool) {
        return _processPayment(
            _configuration[msg.sender][this.processAssigning.selector][configSalt].accessControl,
            _configuration[msg.sender][this.processAssigning.selector][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleExecutionParams),
            originalMsgSender
        );
    }

    function processUnassigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata ruleExecutionParams
    ) external returns (bool) {
        return _processPayment(
            _configuration[msg.sender][this.processUnassigning.selector][configSalt].accessControl,
            _configuration[msg.sender][this.processUnassigning.selector][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleExecutionParams),
            originalMsgSender
        );
    }

    function _processPayment(
        address accessControl,
        PaymentConfiguration memory paymentConfiguration,
        PaymentConfiguration memory expectedPaymentConfiguration,
        address payer
    ) internal returns (bool) {
        if (!accessControl.hasAccess(payer, SKIP_PAYMENT_PID)) {
            _processPayment(paymentConfiguration, expectedPaymentConfiguration, payer);
        }
        return true;
    }

    function _validateSelector(bytes4 ruleSelector) internal pure {
        require(
            ruleSelector == this.processCreation.selector || ruleSelector == this.processAssigning.selector
                || ruleSelector == this.processRemoval.selector || ruleSelector == this.processUnassigning.selector
        );
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == ACCESS_CONTROL_PARAM_KEY) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            }
        }
        configuration.paymentConfiguration = _extractPaymentConfigurationFromParams(params);
        return configuration;
    }
}
