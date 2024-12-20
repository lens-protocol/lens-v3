// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract SimplePaymentRule {
    using SafeERC20 for IERC20;

    event Lens_SimplePaymentRule_Trusted(address indexed payer, address indexed trusted);
    event Lens_SimplePaymentRule_Untrusted(address indexed payer, address indexed untrusted);

    // keccak256("lens.rules.SimplePaymentRule.param.key.paymentConfiguration");
    bytes32 internal immutable PAYMENT_CONFIG_PARAM_KEY =
        0x91813a72876e8e72632a605170833caa3bcd468944917f7e9f54ddb630a3a4b9;

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
