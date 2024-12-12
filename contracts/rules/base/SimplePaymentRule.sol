// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {KeyValue} from "./../../core/types/Types.sol";

abstract contract SimplePaymentRule {
    using SafeERC20 for IERC20;

    event Lens_SimplePaymentRule_Trusted(address indexed payer, address indexed trusted);
    event Lens_SimplePaymentRule_Untrusted(address indexed payer, address indexed untrusted);

    // keccak256("lens.rules.SimplePaymentRule.param.key.SimplePaymentRule.token");
    bytes32 internal immutable TOKEN_PARAM_KEY = 0x939d4466b6f6b9668efcbb71a0462251da210f9d4efc693bd9237a40856d3a29;
    // keccak256("lens.rules.SimplePaymentRule.param.key.SimplePaymentRule.amount");
    bytes32 internal immutable AMOUNT_PARAM_KEY = 0x9c3a14dcd9aca59325efccbcd161d7e895cfac4d505ee55e7c5d112c8b158fc7;
    // keccak256("lens.rules.SimplePaymentRule.param.key.SimplePaymentRule.recipient");
    bytes32 internal immutable RECIPIENT_PARAM_KEY = 0x61fd11d2487c4e4bcd71a48425414930ff42f514a3a79bbb78c78d445d41036c;

    struct PaymentConfiguration {
        address token;
        uint256 amount;
        address recipient;
    }

    mapping(address => mapping(address => bool)) internal _isTrusted;

    function setTrust(address primitive, bool isTrusted) external virtual {
        _isTrusted[msg.sender][primitive] = isTrusted;
        if (isTrusted) {
            emit Lens_SimplePaymentRule_Trusted(msg.sender, primitive);
        } else {
            emit Lens_SimplePaymentRule_Untrusted(msg.sender, primitive);
        }
    }

    function _extractPaymentConfigurationFromParams(KeyValue[] calldata params)
        internal
        pure
        returns (PaymentConfiguration memory)
    {
        PaymentConfiguration memory paymentConfiguration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == TOKEN_PARAM_KEY) {
                paymentConfiguration.token = abi.decode(params[i].value, (address));
            } else if (params[i].key == AMOUNT_PARAM_KEY) {
                paymentConfiguration.amount = abi.decode(params[i].value, (uint256));
            } else if (params[i].key == RECIPIENT_PARAM_KEY) {
                paymentConfiguration.recipient = abi.decode(params[i].value, (address));
            }
        }
        return paymentConfiguration;
    }

    function _validatePaymentConfiguration(PaymentConfiguration memory configuration) internal view virtual {
        require(configuration.amount > 0, "Errors.CannotSetZeroAmount()");
        // Expects token to support ERC-20 interface, we call balanceOf and expect it to not revert
        IERC20(configuration.token).balanceOf(address(this));
    }

    function _beforePayment(
        PaymentConfiguration memory configuration,
        PaymentConfiguration memory expectedConfiguration,
        address payer
    ) internal view virtual {
        require(configuration.token == expectedConfiguration.token, "Errors.UnexpectedToken()");
        require(configuration.amount == expectedConfiguration.amount, "Errors.UnexpectedAmount()");
        require(configuration.recipient == expectedConfiguration.recipient, "Errors.UnexpectedRecipient()");
        // Requires payer to trust the msg.sender, which is acting as the primitive
        require(_isTrusted[payer][msg.sender]);
    }

    function _processPayment(
        PaymentConfiguration memory configuration,
        PaymentConfiguration memory expectedConfiguration,
        address payer
    ) internal virtual {
        _beforePayment(configuration, expectedConfiguration, payer);
        IERC20(configuration.token).safeTransferFrom(payer, configuration.recipient, configuration.amount);
    }
}
