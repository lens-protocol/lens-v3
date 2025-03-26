// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IFollowRule} from "contracts/core/interfaces/IFollowRule.sol";
import {SimplePaymentRule} from "contracts/rules/base/SimplePaymentRule.sol";
import {KeyValue, RecipientData} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {BPS_MAX} from "contracts/core/types/Constants.sol";

contract SimplePaymentFollowRule is SimplePaymentRule, Initializable, IFollowRule {
    /// @custom:keccak lens.param.referrals
    bytes32 constant PARAM__REFERRALS = 0x183a1b7fdb9626f5ae4e8cac88ee13cc03b29800d2690f61e2a2566f76d8773f;
    /// @custom:keccak lens.param.referralFee
    bytes32 constant PARAM__REFERRAL_FEE = 0x6dff2c1710f2154b19d8cf5d6f7d8f5b3909222c3cdd8801486403e4d423b1b6;

    /// @custom:keccak lens.storage.SimplePaymentFollowRule
    bytes32 constant STORAGE__SIMPLE_PAYMENT_FOLLOW_RULE =
        0x40d861d20f0413c082c732a37b8aa34f7a2abf2d3b8a62e3868805a8505f8fd5;

    struct Configuration {
        PaymentConfiguration paymentConfiguration;
        uint16 referralFeeBps;
    }

    struct Storage {
        mapping(address graph => mapping(address account => mapping(bytes32 configSalt => Configuration config)))
            configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__SIMPLE_PAYMENT_FOLLOW_RULE
        }
    }

    constructor() SimplePaymentRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        SimplePaymentRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, address account, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        require(configuration.referralFeeBps <= BPS_MAX, Errors.InvalidParameter());
        _validatePaymentConfiguration(configuration.paymentConfiguration);
        $storage().configuration[msg.sender][account][configSalt].paymentConfiguration =
            configuration.paymentConfiguration;
        $storage().configuration[msg.sender][account][configSalt].referralFeeBps = configuration.referralFeeBps;
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
            configuration: $storage().configuration[msg.sender][accountToFollow][configSalt].paymentConfiguration,
            expectedConfiguration: _extractPaymentConfigurationFromParams(ruleParams),
            payer: followerAccount,
            referrals: _extractReferralsFromParams(ruleParams),
            referralFeeBps: $storage().configuration[msg.sender][accountToFollow][configSalt].referralFeeBps
        });
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__REFERRAL_FEE) {
                configuration.referralFeeBps = abi.decode(params[i].value, (uint16));
            } else if (params[i].key == PARAM__PAYMENT_CONFIG) {
                configuration.paymentConfiguration = abi.decode(params[i].value, (PaymentConfiguration));
            }
        }
        return configuration;
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
}
