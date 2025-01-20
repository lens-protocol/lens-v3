// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {TrustBasedRule} from "contracts/rules/base/TrustBasedRule.sol";

abstract contract SimplePaymentRule is TrustBasedRule, MetadataBased {
    using SafeERC20 for IERC20;

    event Lens_Rule_MetadataURISet(string metadataURI);

    /// @custom:keccak lens.param.paymentConfiguration
    bytes32 constant PARAM__PAYMENT_CONFIG = 0x1d614931e4da442dfded7a7b2023927603d40081577686bb6fd4debb2fd73fc0;

    struct PaymentConfiguration {
        address token;
        uint256 amount;
        address recipient;
    }

    constructor(string memory metadataURI) {
        _setMetadataURI(metadataURI);
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Rule_MetadataURISet(metadataURI);
    }

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
        IERC20(configuration.token).safeTransferFrom(payer, configuration.recipient, configuration.amount);
    }
}
