// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {SimplePaymentRule} from "contracts/rules/base/SimplePaymentRule.sol";
import {KeyValue} from "contracts/core/types/Types.sol";

contract UsernamePricePerLengthNamespaceRule is SimplePaymentRule, INamespaceRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak lens.permission.SkipPayment
    uint256 constant PID__SKIP_PAYMENT = uint256(0x00f37ae888d55466c7f464a414e84bc629550dc0e0655302b62e8c608a260b5c);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;
    /// @custom:keccak lens.param.pricePerLengthConfig
    bytes32 constant PARAM__PRICE_PER_LENGTH = 0xfb5b606f0631eb09d9455c5a3bac25917b3cea6dfc6127937a7a18264219cb27;

    struct Configuration {
        address accessControl;
        PaymentConfiguration defaultConfig;
        mapping(uint256 => Price) pricePerLength;
    }

    struct LengthPriceConfig {
        bool setCustomPrice;
        uint256 length;
        uint256 price;
    }

    struct Price {
        bool isSet;
        uint256 price;
    }

    mapping(address => mapping(bytes32 => Configuration)) internal _configuration;

    constructor(address owner, string memory metadataURI) SimplePaymentRule(owner, metadataURI) {
        emit Events.Lens_PermissionId_Available(PID__SKIP_PAYMENT, "lens.permission.SkipPayment");
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleConfigurationParams) external {
        _extractAndSaveConfigurationFromParams(configSalt, ruleConfigurationParams);
        _configuration[msg.sender][configSalt].accessControl.verifyHasAccessFunction();
        _validatePaymentConfiguration(_configuration[msg.sender][configSalt].defaultConfig);
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external {
        _processPayment(configSalt, originalMsgSender, username, _extractPaymentConfigurationFromParams(ruleParams));
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external {
        _processPayment(configSalt, originalMsgSender, username, _extractPaymentConfigurationFromParams(ruleParams));
    }

    function processAssigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external {
        _processPayment(configSalt, originalMsgSender, username, _extractPaymentConfigurationFromParams(ruleParams));
    }

    function processUnassigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external {
        _processPayment(configSalt, originalMsgSender, username, _extractPaymentConfigurationFromParams(ruleParams));
    }

    function _processPayment(
        bytes32 configSalt,
        address payer,
        string calldata username,
        PaymentConfiguration memory expectedPaymentConfiguration
    ) internal {
        PaymentConfiguration memory paymentConfiguration = _configuration[msg.sender][configSalt].defaultConfig;
        Price memory pricePerLength = _configuration[msg.sender][configSalt].pricePerLength[bytes(username).length];
        if (pricePerLength.isSet) {
            paymentConfiguration.amount = pricePerLength.price;
        }
        if (!_configuration[msg.sender][configSalt].accessControl.hasAccess(payer, PID__SKIP_PAYMENT)) {
            _processPayment(paymentConfiguration, expectedPaymentConfiguration, payer);
        }
    }

    function _extractAndSaveConfigurationFromParams(bytes32 configSalt, KeyValue[] calldata params) internal {
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                _configuration[msg.sender][configSalt].accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__PAYMENT_CONFIG) {
                _configuration[msg.sender][configSalt].defaultConfig =
                    abi.decode(params[i].value, (PaymentConfiguration));
            } else if (params[i].key == PARAM__PRICE_PER_LENGTH) {
                LengthPriceConfig[] memory pricePerLengthConfig = abi.decode(params[i].value, (LengthPriceConfig[]));
                for (uint256 j = 0; j < pricePerLengthConfig.length; j++) {
                    _configuration[msg.sender][configSalt].pricePerLength[pricePerLengthConfig[j].length] =
                        Price({isSet: pricePerLengthConfig[j].setCustomPrice, price: pricePerLengthConfig[j].price});
                }
            }
        }
    }

    function _extractPaymentConfigurationFromParams(KeyValue[] calldata params)
        internal
        pure
        returns (PaymentConfiguration memory)
    {
        PaymentConfiguration memory paymentConfiguration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__PAYMENT_CONFIG) {
                paymentConfiguration = abi.decode(params[i].value, (PaymentConfiguration));
                break;
            }
        }
        return paymentConfiguration;
    }

    function _validatePaymentConfiguration(PaymentConfiguration memory configuration) internal view virtual override {
        // Expects token to support ERC-20 interface, we call balanceOf and expect it to not revert
        IERC20(configuration.token).balanceOf(address(this));
    }
}
