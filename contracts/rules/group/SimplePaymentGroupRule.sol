// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {SimplePaymentRule} from "contracts/rules/base/SimplePaymentRule.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {Events} from "contracts/core/types/Events.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract SimplePaymentGroupRule is SimplePaymentRule, IGroupRule {
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

    constructor(string memory metadataURI) SimplePaymentRule(metadataURI) {
        emit Events.Lens_PermissionId_Available(PID__SKIP_PAYMENT, "lens.permission.SkipPayment");
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        configuration.accessControl.verifyHasAccessFunction();
        _validatePaymentConfiguration(configuration.paymentConfiguration);
        _configuration[msg.sender][configSalt] = configuration;
    }

    function processAddition(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure {
        revert Errors.NotImplemented();
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure {
        revert Errors.NotImplemented();
    }

    function processJoining(
        bytes32 configSalt,
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external {
        _processPayment(
            _configuration[msg.sender][configSalt].accessControl,
            _configuration[msg.sender][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleParams),
            account
        );
    }

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure {
        revert Errors.NotImplemented();
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
            }
        }
        return paymentConfiguration;
    }
}
