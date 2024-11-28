// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IFollowRule} from "./../../core/interfaces/IFollowRule.sol";
import {SimplePaymentRule} from "./../base/SimplePaymentRule.sol";

contract SimplePaymentFollowRule is SimplePaymentRule, IFollowRule {
    mapping(address => mapping(address => PaymentConfiguration)) internal _configuration;

    function configure(address account, bytes calldata data) external {
        PaymentConfiguration memory configuration = abi.decode(data, (PaymentConfiguration));
        _validatePaymentConfiguration(configuration);
        _configuration[msg.sender][account] = configuration;
    }

    function processFollow(
        address followerAccount,
        address accountToFollow,
        bytes calldata data
    ) external returns (bool) {
        _processPayment(
            _configuration[msg.sender][accountToFollow], abi.decode(data, (PaymentConfiguration)), followerAccount
        );
        return true;
    }
}
