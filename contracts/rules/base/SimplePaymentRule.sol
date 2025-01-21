// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {TrustBasedRule} from "contracts/rules/base/TrustBasedRule.sol";
import {PaymentHandler} from "contracts/core/base/PaymentHandler.sol";

abstract contract SimplePaymentRule is PaymentHandler, TrustBasedRule, OwnableMetadataBasedRule {
    /// @custom:keccak lens.param.paymentConfiguration
    bytes32 constant PARAM__PAYMENT_CONFIG = 0x1d614931e4da442dfded7a7b2023927603d40081577686bb6fd4debb2fd73fc0;

    struct PaymentConfiguration {
        address token;
        uint256 amount;
        address recipient;
    }

    constructor(address owner, string memory metadataURI) OwnableMetadataBasedRule(owner, metadataURI) {}

    function _validatePaymentConfiguration(PaymentConfiguration memory configuration) internal view virtual {
        require(configuration.amount > 0, Errors.InvalidParameter());
        // Expects token to support ERC-20 interface, we call balanceOf and expect it to not revert
        IERC20(configuration.token).balanceOf(address(this));
    }

    function _beforePayment(
        PaymentConfiguration memory configuration,
        PaymentConfiguration memory expectedConfiguration,
        address payer
    ) internal view virtual {
        require(configuration.token == expectedConfiguration.token, Errors.InvalidParameter());
        require(configuration.amount == expectedConfiguration.amount, Errors.InvalidParameter());
        require(configuration.recipient == expectedConfiguration.recipient, Errors.InvalidParameter());
        // Requires payer to trust the msg.sender, which is acting as the primitive
        _requireTrust({fromAccount: payer, toTarget: msg.sender});
    }

    function _processPayment(
        PaymentConfiguration memory configuration,
        PaymentConfiguration memory expectedConfiguration,
        address payer
    ) internal virtual {
        _beforePayment(configuration, expectedConfiguration, payer);
        _handlePayment(configuration.token, payer, configuration.recipient, configuration.amount);
    }
}
