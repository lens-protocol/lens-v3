// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroupRule} from "./../../core/interfaces/IGroupRule.sol";
import {SimplePaymentRule} from "./../base/SimplePaymentRule.sol";

contract SimplePaymentGroupRule is SimplePaymentRule, IGroupRule {
    mapping(address => PaymentConfiguration) internal _configuration;

    function configure(bytes calldata data) external {
        PaymentConfiguration memory configuration = abi.decode(data, (PaymentConfiguration));
        _validatePaymentConfiguration(configuration);
        _configuration[msg.sender] = configuration;
    }

    function processJoining(address account, bytes calldata data) external returns (bool) {
        _processPayment(_configuration[msg.sender], abi.decode(data, (PaymentConfiguration)), account);
        return true;
    }

    function processRemoval(address, /* account */ bytes calldata /*data*/ ) external pure returns (bool) {
        return false;
    }
}
