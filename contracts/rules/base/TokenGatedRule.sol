// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IToken {
    /**
     * @dev Returns the amount of ERC20/ERC721 tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
}

abstract contract TokenGatedRule {
    uint256 internal constant ERC20 = 20;
    uint256 internal constant ERC721 = 721;
    uint256 internal constant ERC1155 = 1155;

    // keccak256("lens.rules.TokenGatedRule.param.key.tokenGate");
    bytes32 internal immutable TOKEN_GATE_PARAM_KEY = 0x5b35354681265fb29cacc9eee788924889b95a232ef90388f970779780c3ce3b;

    struct TokenGateConfiguration {
        uint256 tokenStandard;
        address token;
        uint256 typeId; // Optional, only for ERC-1155 tokens. Use 0 for ERC-20/ERC-721 tokens.
        uint256 amount;
    }

    function _validateTokenGateConfiguration(TokenGateConfiguration memory configuration) internal view {
        require(configuration.amount > 0, "Errors.CannotSetZeroAmount()");
        if (configuration.tokenStandard == ERC20 || configuration.tokenStandard == ERC721) {
            // Expects token to support ERC-20/ERC-721 balanceOf by not reverting
            IToken(configuration.token).balanceOf(address(this));
        } else if (configuration.tokenStandard == ERC1155) {
            // Expects token to support ERC-1155 balanceOf by not reverting
            IERC1155(configuration.token).balanceOf(address(this), configuration.typeId);
        } else {
            revert("Errors.InvalidTokenStandard()");
        }
    }

    function _validateTokenBalance(TokenGateConfiguration memory configuration, address owner) internal view {
        uint256 balance;
        if (configuration.tokenStandard == ERC20 || configuration.tokenStandard == ERC721) {
            balance = IToken(configuration.token).balanceOf(owner);
        } else {
            balance = IERC1155(configuration.token).balanceOf(owner, configuration.typeId);
        }
        require(balance >= configuration.amount, "Errors.InsufficientTokenBalance()");
    }
}
