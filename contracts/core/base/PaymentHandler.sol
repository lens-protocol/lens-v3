// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";

contract PaymentHandler {
    using SafeERC20 for IERC20;
    using CallLib for address;

    address internal constant NATIVE_TOKEN = address(0x800A);

    function _handlePayment(address token, address from, address to, uint256 amount) internal {
        if (token == NATIVE_TOKEN) {
            require(msg.value >= amount, Errors.InvalidParameter());
            to.handledcall(msg.value, "");
        } else {
            IERC20(token).safeTransferFrom(from, to, amount);
        }
    }
}
