// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IFollowRule} from "./../../core/interfaces/IFollowRule.sol";
import {TokenGatedRule} from "./../base/TokenGatedRule.sol";

contract TokenGatedFollowRule is TokenGatedRule, IFollowRule {
    mapping(address => mapping(address => TokenGateConfiguration)) internal _configuration;

    function configure(address account, bytes calldata data) external {
        TokenGateConfiguration memory configuration = abi.decode(data, (TokenGateConfiguration));
        _validateTokenGateConfiguration(configuration);
        _configuration[msg.sender][account] = configuration;
    }

    function processFollow(
        address followerAccount,
        address accountToFollow,
        bytes calldata /* data */
    ) external view returns (bool) {
        _validateTokenBalance(_configuration[msg.sender][accountToFollow], followerAccount);
        return true;
    }
}
