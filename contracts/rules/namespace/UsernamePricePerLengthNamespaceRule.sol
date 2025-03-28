// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {SimplePaymentRule} from "contracts/rules/base/SimplePaymentRule.sol";
import {KeyValue, RecipientData} from "contracts/core/types/Types.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {BPS_MAX} from "contracts/core/types/Constants.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract UsernamePricePerLengthNamespaceRule is SimplePaymentRule, Initializable, INamespaceRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak lens.permission.SkipPayment
    uint256 constant PID__SKIP_PAYMENT = uint256(0x00f37ae888d55466c7f464a414e84bc629550dc0e0655302b62e8c608a260b5c);

    /// @custom:keccak lens.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0xcf3b0fab90208e4185bf857e0f943f6672abffb7d0898e0750beeeb991ae35fa;
    /// @custom:keccak lens.param.referrals
    bytes32 constant PARAM__REFERRALS = 0x183a1b7fdb9626f5ae4e8cac88ee13cc03b29800d2690f61e2a2566f76d8773f;
    /// @custom:keccak lens.param.referralFee
    bytes32 constant PARAM__REFERRAL_FEE = 0x6dff2c1710f2154b19d8cf5d6f7d8f5b3909222c3cdd8801486403e4d423b1b6;
    /// @custom:keccak lens.param.pricePerLengthConfig
    bytes32 constant PARAM__PRICE_PER_LENGTH = 0xfb5b606f0631eb09d9455c5a3bac25917b3cea6dfc6127937a7a18264219cb27;

    /// @custom:keccak lens.storage.UsernamePricePerLengthNamespaceRule
    bytes32 constant STORAGE__USERNAME_PRICE_PER_LENGTH_NAMESPACE_RULE =
        0x30c135f7e439d20e948372fefb19fe2e3bba93558b8f166d2139949a2055326f;

    struct Configuration {
        address accessControl;
        uint16 referralFeeBps;
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

    struct Storage {
        mapping(address namespace => mapping(bytes32 configSalt => Configuration config)) configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__USERNAME_PRICE_PER_LENGTH_NAMESPACE_RULE
        }
    }

    constructor() SimplePaymentRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Lens_PermissionId_Available(PID__SKIP_PAYMENT, "lens.permission.SkipPayment");
        SimplePaymentRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleConfigurationParams) external override {
        _extractAndSaveConfigurationFromParams(configSalt, ruleConfigurationParams);
        $storage().configuration[msg.sender][configSalt].accessControl.verifyHasAccessFunction();
        require($storage().configuration[msg.sender][configSalt].referralFeeBps <= BPS_MAX, Errors.InvalidParameter());
        _validatePaymentConfiguration($storage().configuration[msg.sender][configSalt].defaultConfig);
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment(
            configSalt,
            originalMsgSender,
            username,
            _extractPaymentConfigurationFromParams(ruleParams),
            _extractReferralsFromParams(ruleParams)
        );
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment(
            configSalt,
            originalMsgSender,
            username,
            _extractPaymentConfigurationFromParams(ruleParams),
            _extractReferralsFromParams(ruleParams)
        );
    }

    function processAssigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment(
            configSalt,
            originalMsgSender,
            username,
            _extractPaymentConfigurationFromParams(ruleParams),
            _extractReferralsFromParams(ruleParams)
        );
    }

    function processUnassigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment(
            configSalt,
            originalMsgSender,
            username,
            _extractPaymentConfigurationFromParams(ruleParams),
            _extractReferralsFromParams(ruleParams)
        );
    }

    function _processPayment(
        bytes32 configSalt,
        address payer,
        string calldata username,
        PaymentConfiguration memory expectedPaymentConfiguration,
        RecipientData[] memory referrals
    ) internal {
        PaymentConfiguration memory paymentConfiguration = $storage().configuration[msg.sender][configSalt].defaultConfig;
        Price memory pricePerLength =
            $storage().configuration[msg.sender][configSalt].pricePerLength[bytes(username).length];
        if (pricePerLength.isSet) {
            paymentConfiguration.amount = pricePerLength.price;
        }
        if (!$storage().configuration[msg.sender][configSalt].accessControl.hasAccess(payer, PID__SKIP_PAYMENT)) {
            _processPayment(
                paymentConfiguration,
                expectedPaymentConfiguration,
                payer,
                referrals,
                $storage().configuration[msg.sender][configSalt].referralFeeBps
            );
        }
    }

    function _extractAndSaveConfigurationFromParams(bytes32 configSalt, KeyValue[] calldata params) internal {
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                $storage().configuration[msg.sender][configSalt].accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__PAYMENT_CONFIG) {
                $storage().configuration[msg.sender][configSalt].defaultConfig =
                    abi.decode(params[i].value, (PaymentConfiguration));
            } else if (params[i].key == PARAM__REFERRAL_FEE) {
                $storage().configuration[msg.sender][configSalt].referralFeeBps = abi.decode(params[i].value, (uint16));
            } else if (params[i].key == PARAM__PRICE_PER_LENGTH) {
                LengthPriceConfig[] memory pricePerLengthConfig = abi.decode(params[i].value, (LengthPriceConfig[]));
                for (uint256 j = 0; j < pricePerLengthConfig.length; j++) {
                    $storage().configuration[msg.sender][configSalt].pricePerLength[pricePerLengthConfig[j].length] =
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

    function _extractReferralsFromParams(KeyValue[] calldata params) internal pure returns (RecipientData[] memory) {
        RecipientData[] memory referrals = new RecipientData[](0);
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__REFERRALS) {
                referrals = abi.decode(params[i].value, (RecipientData[]));
                break;
            }
        }
        return referrals;
    }

    function _validatePaymentConfiguration(PaymentConfiguration memory configuration) internal view virtual override {
        // Expects token to support ERC-20 interface, we call balanceOf and expect it to not revert
        IERC20(configuration.token).balanceOf(address(this));
    }
}
