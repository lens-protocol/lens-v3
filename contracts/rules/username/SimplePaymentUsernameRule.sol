// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../core/interfaces/IAccessControl.sol";
import {IUsernameRule} from "./../../core/interfaces/IUsernameRule.sol";
import {AccessControlLib} from "./../../core/libraries/AccessControlLib.sol";
import {Events} from "./../../core/types/Events.sol";
import {SimplePaymentRule} from "./../base/SimplePaymentRule.sol";

contract SimplePaymentUsernameRule is SimplePaymentRule, IUsernameRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    uint256 constant SKIP_PAYMENT_PID = uint256(keccak256("SKIP_PAYMENT"));

    struct RestrictionConfiguration {
        bool restrictCreation;
        bool restrictAssigning;
    }

    struct Configuration {
        address accessControl;
        RestrictionConfiguration restrictions;
        PaymentConfiguration paymentConfiguration;
    }

    mapping(address => Configuration) internal _configuration;

    constructor() {
        emit Events.Lens_PermissionId_Available(SKIP_PAYMENT_PID, "SKIP_PAYMENT");
    }

    function configure(bytes calldata data) external {
        Configuration memory configuration = abi.decode(data, (Configuration));
        configuration.accessControl.verifyHasAccessFunction();
        _validatePaymentConfiguration(configuration.paymentConfiguration);
        require(
            configuration.restrictions.restrictCreation || configuration.restrictions.restrictAssigning,
            "Username: no restrictions"
        );
        _configuration[msg.sender] = configuration;
    }

    function processCreation(
        address account,
        string calldata, /* username */
        bytes calldata data
    ) external returns (bool) {
        return _processPayment(
            _configuration[msg.sender].restrictions.restrictCreation,
            _configuration[msg.sender].accessControl,
            _configuration[msg.sender].paymentConfiguration,
            abi.decode(data, (PaymentConfiguration)),
            account
        );
    }

    function processAssigning(
        address account,
        string calldata, /* username */
        bytes calldata data
    ) external returns (bool) {
        return _processPayment(
            _configuration[msg.sender].restrictions.restrictAssigning,
            _configuration[msg.sender].accessControl,
            _configuration[msg.sender].paymentConfiguration,
            abi.decode(data, (PaymentConfiguration)),
            account
        );
    }

    function _processPayment(
        bool isRestricted,
        address accessControl,
        PaymentConfiguration memory paymentConfiguration,
        PaymentConfiguration memory expectedPaymentConfiguration,
        address payer
    ) internal returns (bool) {
        if (isRestricted && !accessControl.hasAccess(payer, SKIP_PAYMENT_PID)) {
            _processPayment(paymentConfiguration, expectedPaymentConfiguration, payer);
        }
        return true;
    }
}
