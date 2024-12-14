// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IFollowRule} from "./../../core/interfaces/IFollowRule.sol";
import {SimplePaymentRule} from "./../base/SimplePaymentRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {KeyValue} from "./../../core/types/Types.sol";
import {Events} from "./../../core/types/Events.sol";

contract SimplePaymentFollowRule is SimplePaymentRule, IFollowRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant SKIP_PAYMENT_PID = uint256(keccak256("SKIP_PAYMENT"));

    // keccak256("lens.param.key.accessControl");
    bytes32 immutable ACCESS_CONTROL_PARAM_KEY = 0x6552dd4db64bdb68f2725e4865ecb072df1c2befcfb455b69e2d2b886a8e185e;

    struct Configuration {
        address accessControl;
        PaymentConfiguration paymentConfiguration;
    }

    mapping(address => mapping(address => mapping(bytes4 => mapping(bytes32 => Configuration)))) internal _configuration;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_PAYMENT_PID, "SKIP_PAYMENT");
    }

    function configure(
        address account,
        bytes4 ruleSelector,
        bytes32 salt,
        KeyValue[] calldata ruleConfigurationParams
    ) external {
        _validateSelector(ruleSelector);
        Configuration memory configuration = _extractConfigurationFromParams(ruleConfigurationParams);
        configuration.accessControl.verifyHasAccessFunction();
        _validatePaymentConfiguration(configuration.paymentConfiguration);
        _configuration[msg.sender][account][ruleSelector][salt] = configuration;
    }

    function processFollow(
        bytes32 configSalt,
        address, /* originalMsgSender */
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata ruleExecutionParams
    ) external {
        _processPayment(
            _configuration[msg.sender][accountToFollow][this.processFollow.selector][configSalt].accessControl,
            _configuration[msg.sender][accountToFollow][this.processFollow.selector][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleExecutionParams),
            followerAccount
        );
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

    function _validateSelector(bytes4 ruleSelector) internal pure {
        require(ruleSelector == this.processFollow.selector);
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
