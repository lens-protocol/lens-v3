// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IFollowRule} from "contracts/core/interfaces/IFollowRule.sol";
import {SimplePaymentRule} from "contracts/rules/base/SimplePaymentRule.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract SimplePaymentFollowRule is SimplePaymentRule, IFollowRule {
    mapping(address => mapping(address => mapping(bytes32 => PaymentConfiguration))) internal _paymentConfiguration;

    constructor(address owner, string memory metadataURI) SimplePaymentRule(owner, metadataURI) {}

    function configure(bytes32 configSalt, address account, KeyValue[] calldata ruleParams) external override {
        PaymentConfiguration memory paymentConfiguration = _extractPaymentConfigurationFromParams(ruleParams);
        _validatePaymentConfiguration(paymentConfiguration);
        _paymentConfiguration[msg.sender][account][configSalt] = paymentConfiguration;
    }

    function processFollow(
        bytes32 configSalt,
        address, /* originalMsgSender */
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment({
            configuration: _paymentConfiguration[msg.sender][accountToFollow][configSalt],
            expectedConfiguration: _extractPaymentConfigurationFromParams(ruleParams),
            payer: followerAccount
        });
    }

    function _extractPaymentConfigurationFromParams(KeyValue[] calldata params)
        internal
        pure
        returns (PaymentConfiguration memory)
    {
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__PAYMENT_CONFIG) {
                return abi.decode(params[i].value, (PaymentConfiguration));
            }
        }
        revert Errors.NotFound();
    }
}
