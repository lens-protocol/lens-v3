// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IFollowRule} from "contracts/core/interfaces/IFollowRule.sol";
import {TokenGatedRule} from "contracts/rules/base/TokenGatedRule.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract TokenGatedFollowRule is TokenGatedRule, Initializable, IFollowRule {
    mapping(address => mapping(address => mapping(bytes32 => TokenGateConfiguration))) internal _tokenGateConfig;

    constructor() TokenGatedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        TokenGatedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, address account, KeyValue[] calldata ruleParams) external override {
        TokenGateConfiguration memory tokenGateConfig = _extractConfigurationFromParams(ruleParams);
        _validateTokenGateConfiguration(tokenGateConfig);
        _tokenGateConfig[msg.sender][account][configSalt] = tokenGateConfig;
    }

    function processFollow(
        bytes32 configSalt,
        address, /* originalMsgSender */
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(_tokenGateConfig[msg.sender][accountToFollow][configSalt], followerAccount);
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params)
        internal
        pure
        returns (TokenGateConfiguration memory)
    {
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__TOKEN_GATE) {
                return abi.decode(params[i].value, (TokenGateConfiguration));
            }
        }
        revert Errors.NotFound();
    }
}
