// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {LensPaymentHandler} from "contracts/extensions/fees/LensPaymentHandler.sol";
import {ILensNativePaymentHelper} from "contracts/extensions/fees/LensNativePaymentHelper.sol";
import {LENS_CREATE_2_ADDRESS, ILensCreate2} from "contracts/core/upgradeability/LensCreate2.sol";
import {CONTRACT__LENS_NATIVE_PAYMENT_HELPER, NATIVE_TOKEN} from "contracts/core/types/Constants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract LensRulePaymentHandler is LensPaymentHandler {
    using SafeERC20 for IERC20;

    ILensNativePaymentHelper private immutable LENS_NATIVE_PAYMENT_HELPER;

    constructor() {
        LENS_NATIVE_PAYMENT_HELPER = ILensNativePaymentHelper(
            ILensCreate2(LENS_CREATE_2_ADDRESS).getAddress(CONTRACT__LENS_NATIVE_PAYMENT_HELPER)
        );
    }

    function _sendToken(address token, address payer, address recipient, uint256 amount) internal virtual override {
        if (token == NATIVE_TOKEN) {
            LENS_NATIVE_PAYMENT_HELPER.transferNative(recipient, amount);
        } else {
            IERC20(token).safeTransferFrom(payer, recipient, amount);
        }
    }
}
