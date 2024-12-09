// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGraphRule} from "./../../core/interfaces/IGraphRule.sol";
import {RuleChange} from "./../../core/types/Types.sol";
import {TokenGatedRule} from "./../base/TokenGatedRule.sol";

contract TokenGatedGraphRule is TokenGatedRule, IGraphRule {
    mapping(address => TokenGateConfiguration) internal _configuration;

    function configure(bytes calldata data) external override {
        TokenGateConfiguration memory configuration = abi.decode(data, (TokenGateConfiguration));
        _validateTokenGateConfiguration(configuration);
        _configuration[msg.sender] = configuration;
    }

    function processFollow(
        address followerAccount,
        address accountToFollow,
        bytes calldata /* data */
    ) external view returns (bool) {
        TokenGateConfiguration memory configuration = _configuration[msg.sender];
        /**
         * Both ends of the follow connection must comply with the token-gate restriction, then the graph is purely
         * conformed by token holders.
         */
        _validateTokenBalance(configuration, followerAccount);
        _validateTokenBalance(configuration, accountToFollow);
        return true;
    }

    function processFollowRuleChanges(
        address, /* account */
        RuleChange[] calldata, /* ruleChanges */
        bytes calldata /* data */
    ) external pure returns (bool) {
        return false;
    }
}
