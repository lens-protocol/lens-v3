// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IFollowRule} from "contracts/core/interfaces/IFollowRule.sol";
import {SimplePaymentRule} from "contracts/rules/base/SimplePaymentRule.sol";
import {KeyValue, RecipientData} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract SimplePaymentFollowRule is SimplePaymentRule, Initializable, IFollowRule {
    /// @custom:keccak lens.param.referrals
    bytes32 constant PARAM__REFERRALS = 0x183a1b7fdb9626f5ae4e8cac88ee13cc03b29800d2690f61e2a2566f76d8773f;
    /// @custom:keccak lens.param.referralFeeBps
    bytes32 constant PARAM__REFERRAL_FEE_BPS = 0x0528211c8ce09d8b4bbf47978d7c2b7901461b28da5f4da81efb3058169ea470;

    /// @custom:keccak lens.storage.SimplePaymentFollowRule
    bytes32 constant STORAGE__SIMPLE_PAYMENT_FOLLOW_RULE =
        0x40d861d20f0413c082c732a37b8aa34f7a2abf2d3b8a62e3868805a8505f8fd5;

    struct Storage {
        mapping(address graph => mapping(address account => mapping(bytes32 configSalt => PaymentConfiguration config)))
            paymentConfiguration;
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
        PaymentConfiguration memory paymentConfiguration = _extractPaymentConfigurationFromParams(ruleParams);
        _validatePaymentConfiguration(paymentConfiguration);
        $storage().paymentConfiguration[msg.sender][account][configSalt] = paymentConfiguration;
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
            configuration: $storage().paymentConfiguration[msg.sender][accountToFollow][configSalt],
            expectedConfiguration: _extractPaymentConfigurationFromParams(ruleParams),
            payer: followerAccount,
            referrals: new RecipientData[](0), // TODO: Implement!
            referralFeeBps: 0 // TODO: Implement!
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
