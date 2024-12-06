// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroupRule} from "./../../core/interfaces/IGroupRule.sol";
import {TokenGatedRule} from "./../base/TokenGatedRule.sol";

contract TokenGatedGroupRule is TokenGatedRule, IGroupRule {
    mapping(address => TokenGateConfiguration) internal _configuration;

    function configure(bytes calldata data) external {
        TokenGateConfiguration memory configuration = abi.decode(data, (TokenGateConfiguration));
        _validateTokenGateConfiguration(configuration);
        _configuration[msg.sender] = configuration;
    }

    function processJoining(address account, bytes calldata /* data */ ) external view returns (bool) {
        _validateTokenBalance(_configuration[msg.sender], account);
        return true;
    }

    function processRemoval(address, /* account */ bytes calldata /*data*/ ) external pure returns (bool) {
        return false;
    }
}
