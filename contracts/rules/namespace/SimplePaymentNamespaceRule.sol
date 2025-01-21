// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {SimplePaymentRule} from "contracts/rules/base/SimplePaymentRule.sol";
import {KeyValue} from "contracts/core/types/Types.sol";

contract SimplePaymentNamespaceRule is SimplePaymentRule, INamespaceRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak lens.permission.SkipPayment
    uint256 constant PID__SKIP_PAYMENT = uint256(0x00f37ae888d55466c7f464a414e84bc629550dc0e0655302b62e8c608a260b5c);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;

    struct Configuration {
        address accessControl;
        PaymentConfiguration paymentConfiguration;
    }

    mapping(address => mapping(bytes32 => Configuration)) internal _configuration;

    constructor(address owner, string memory metadataURI) SimplePaymentRule(owner, metadataURI) {
        emit Events.Lens_PermissionId_Available(PID__SKIP_PAYMENT, "lens.permission.SkipPayment");
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleConfigurationParams) external payable {
        Configuration memory configuration = _extractConfigurationFromParams(ruleConfigurationParams);
        configuration.accessControl.verifyHasAccessFunction();
        _validatePaymentConfiguration(configuration.paymentConfiguration);
        _configuration[msg.sender][configSalt] = configuration;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external payable {
        _processPayment(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleParams),
            originalMsgSender
        );
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external payable {
        _processPayment(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleParams),
            originalMsgSender
        );
    }

    function processAssigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external payable {
        _processPayment(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleParams),
            originalMsgSender
        );
    }

    function processUnassigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external payable {
        _processPayment(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleParams),
            originalMsgSender
        );
    }

    function _processPayment(
        address accessControl,
        PaymentConfiguration memory paymentConfiguration,
        PaymentConfiguration memory expectedPaymentConfiguration,
        address payer
    ) internal {
        if (!accessControl.hasAccess(payer, PID__SKIP_PAYMENT)) {
            _processPayment(paymentConfiguration, expectedPaymentConfiguration, payer);
        }
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__PAYMENT_CONFIG) {
                configuration.paymentConfiguration = abi.decode(params[i].value, (PaymentConfiguration));
            }
        }
        return configuration;
    }

    function _extractPaymentConfigurationFromParams(KeyValue[] calldata params)
        internal
        pure
        returns (PaymentConfiguration memory)
    {
        PaymentConfiguration memory paymentConfiguration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__PAYMENT_CONFIG) {
                paymentConfiguration = abi.decode(params[i].value, (PaymentConfiguration));
                break;
            }
        }
        return paymentConfiguration;
    }
}
