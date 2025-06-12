// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";
import {LENS_CREATE_2_ADDRESS, ILensCreate2} from "contracts/core/upgradeability/LensCreate2.sol";
import {ILensNativeHelper} from "contracts/extensions/fees/LensNativeHelper.sol";
import {CONTRACT__LENS_PAYMENT_HELPER} from "contracts/core/types/Constants.sol";

interface ILensNativeHelper {
    function transferNativeTo(address to, uint256 amount) external;
}

/// @title LensNativeHelper
/// @notice This contract is used to help with native token payments during rules fund distribution.
/// @dev We assume that native token is funded here by the primitive in the beginning of TX before all rules, and then
/// @dev is spent by each rule permissionlessly until depleted. In the end of TX, the primitive might transfer the
/// @dev remaining balance back to caller.
contract LensNativeHelper {
    receive() external payable {}

    function transferNativeTo(address to, uint256 amount) external {
        require(amount > address(this).balance, Errors.NotEnoughBalance());
        (bool success,) = to.call{value: amount}("");
        require(success, Errors.FailedToTransferNative());
    }
}

abstract contract UsesLensNativeHelperModifier {
    ILensNativeHelper immutable LENS_PAYMENT_HELPER;

    constructor() {
        LENS_PAYMENT_HELPER =
            ILensNativeHelper(ILensCreate2(LENS_CREATE_2_ADDRESS).getAddress(CONTRACT__LENS_PAYMENT_HELPER));
    }

    modifier usesNativePaymentHelper() {
        if (msg.value > 0) {
            (bool success,) = address(LENS_PAYMENT_HELPER).call{value: msg.value}("");
            require(success, Errors.FailedToTransferNative());
        }
        _;
        uint256 refundAmount = address(LENS_PAYMENT_HELPER).balance;
        if (refundAmount > 0) {
            LENS_PAYMENT_HELPER.transferNativeTo(msg.sender, refundAmount);
        }
    }
}
