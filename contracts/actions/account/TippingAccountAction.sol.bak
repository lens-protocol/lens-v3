// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccountAction} from "./../../core/interfaces/IAccountAction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TippingAccountAction is IAccountAction {
    using SafeERC20 for IERC20;

    function configure(
        address, /* account */
        bytes calldata /* data */
    ) external pure override returns (bytes memory) {
        revert(); // Configuration not needed for tipping.
    }

    function execute(address account, bytes calldata data) external override returns (bytes memory) {
        (address erc20Token, uint256 tipAmount) = abi.decode(data, (address, uint256));
        require(tipAmount > 0);
        IERC20(erc20Token).safeTransferFrom(msg.sender, account, tipAmount);
        emit Lens_AccountAction_Executed(account, data);
        return "";
    }
}
