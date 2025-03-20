// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IFollowRule} from "contracts/core/interfaces/IFollowRule.sol";
import {TokenGatedRule} from "contracts/rules/base/TokenGatedRule.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract TokenGatedFollowRule is TokenGatedRule, Initializable, IFollowRule {
    /// @custom:keccak lens.storage.TokenGatedFollowRule
    bytes32 constant STORAGE__TOKEN_GATED_FOLLOW_RULE =
        0xe97fbf5c7954b514ec4e26886a15690eccfbfbc3d218ff7d2972305cb75c4368;

    struct Storage {
        mapping(
            address graph => mapping(address account => mapping(bytes32 configSalt => TokenGateConfiguration config))
        ) tokenGateConfig;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__TOKEN_GATED_FOLLOW_RULE
        }
    }

    constructor() TokenGatedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        TokenGatedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, address account, KeyValue[] calldata ruleParams) external override {
        TokenGateConfiguration memory tokenGateConfig = _extractConfigurationFromParams(ruleParams);
        _validateTokenGateConfiguration(tokenGateConfig);
        $storage().tokenGateConfig[msg.sender][account][configSalt] = tokenGateConfig;
    }

    function processFollow(
        bytes32 configSalt,
        address, /* originalMsgSender */
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance($storage().tokenGateConfig[msg.sender][accountToFollow][configSalt], followerAccount);
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
