// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroupRule} from "./../../core/interfaces/IGroupRule.sol";
import {SimplePaymentRule} from "./../base/SimplePaymentRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {KeyValue} from "./../../core/types/Types.sol";
import {Events} from "./../../core/types/Events.sol";

contract SimplePaymentGroupRule is SimplePaymentRule, IGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant SKIP_PAYMENT_PID = uint256(keccak256("SKIP_PAYMENT"));

    // keccak256("lens.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0x6552dd4db64bdb68f2725e4865ecb072df1c2befcfb455b69e2d2b886a8e185e;

    struct Configuration {
        address accessControl;
        PaymentConfiguration paymentConfiguration;
    }

    mapping(address => mapping(bytes32 => Configuration)) internal _configuration;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_PAYMENT_PID, "SKIP_PAYMENT");
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
        revert();
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure {
        revert();
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
        revert();
    }

    function _processPayment(
        address accessControl,
        PaymentConfiguration memory paymentConfiguration,
        PaymentConfiguration memory expectedPaymentConfiguration,
        address payer
    ) internal {
        if (!accessControl.hasAccess(payer, SKIP_PAYMENT_PID)) {
            _processPayment(paymentConfiguration, expectedPaymentConfiguration, payer);
        }
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == ACCESS_CONTROL_PARAM_KEY) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PAYMENT_CONFIG_PARAM_KEY) {
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
            if (params[i].key == PAYMENT_CONFIG_PARAM_KEY) {
                paymentConfiguration = abi.decode(params[i].value, (PaymentConfiguration));
            }
        }
        return paymentConfiguration;
    }
}
