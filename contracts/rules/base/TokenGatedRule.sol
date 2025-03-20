// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";

interface IToken {
    /**
     * @dev Returns the amount of ERC20/ERC721 tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
}

abstract contract TokenGatedRule is OwnableMetadataBasedRule {
    uint256 internal constant ERC20 = 20;
    uint256 internal constant ERC721 = 721;
    uint256 internal constant ERC1155 = 1155;

    /// @custom:keccak lens.param.tokenGate
    bytes32 constant PARAM__TOKEN_GATE = 0xb395c61ecf6294b637d557db500d79f61694bd0d2e3c9b0d54383cc4a6c6dcea;

    struct TokenGateConfiguration {
        uint256 tokenStandard;
        address token;
        uint256 typeId; // Optional, only for ERC-1155 tokens. Use 0 for ERC-20/ERC-721 tokens.
        uint256 amount;
    }

    constructor(address owner, string memory metadataURI) OwnableMetadataBasedRule(owner, metadataURI) {}

    function _initialize(address owner, string memory metadataURI) internal override {
        super._initialize(owner, metadataURI);
    }

    function _validateTokenGateConfiguration(TokenGateConfiguration memory configuration) internal view {
        require(configuration.amount > 0, Errors.InvalidParameter());
        if (configuration.tokenStandard == ERC20 || configuration.tokenStandard == ERC721) {
            // Expects token to support ERC-20/ERC-721 balanceOf by not reverting
            IToken(configuration.token).balanceOf(address(this));
        } else if (configuration.tokenStandard == ERC1155) {
            // Expects token to support ERC-1155 balanceOf by not reverting
            IERC1155(configuration.token).balanceOf(address(this), configuration.typeId);
        } else {
            revert Errors.InvalidParameter();
        }
    }

    function _validateTokenBalance(TokenGateConfiguration memory configuration, address owner) internal view {
        require(_checkTokenBalance(configuration, owner), Errors.NotEnough());
    }

    function _checkTokenBalance(TokenGateConfiguration memory configuration, address owner)
        internal
        view
        returns (bool)
    {
        uint256 balance;
        if (configuration.tokenStandard == ERC20 || configuration.tokenStandard == ERC721) {
            balance = IToken(configuration.token).balanceOf(owner);
        } else {
            balance = IERC1155(configuration.token).balanceOf(owner, configuration.typeId);
        }
        return balance >= configuration.amount;
    }
}
