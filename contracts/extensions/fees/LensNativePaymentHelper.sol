// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";
import {LENS_CREATE_2_ADDRESS, ILensCreate2} from "contracts/core/upgradeability/LensCreate2.sol";
import {CONTRACT__LENS_NATIVE_PAYMENT_HELPER} from "contracts/core/types/Constants.sol";

interface ILensNativePaymentHelper {
    function transferNative(address to, uint256 amount) external;
    function refundNative(address to) external;
}

/// @title LensNativePaymentHelper
/// @notice This contract is used to help with native token payments during rules fund distribution.
/// @dev We assume that native token is funded here by the primitive in the beginning of TX before all rules, and then
/// @dev is spent by each rule permissionlessly until depleted. In the end of TX, the primitive might transfer the
/// @dev remaining balance back to caller.
contract LensNativePaymentHelper {
    receive() external payable {}

    function transferNative(address to, uint256 amount) external {
        require(amount <= address(this).balance, Errors.NotEnoughBalance());
        _transferNative(to, amount);
    }

    function refundNative(address to) external {
        uint256 amount = address(this).balance;
        if (amount > 0) {
            _transferNative(to, amount);
        }
    }

    function _transferNative(address to, uint256 amount) internal {
        (bool callSucceeded,) = to.call{value: amount}("");
        require(callSucceeded, Errors.FailedToTransferNative());
    }
}

abstract contract PayableUsingNativePaymentHelper {
    ILensNativePaymentHelper immutable LENS_NATIVE_PAYMENT_HELPER;

    constructor() {
        LENS_NATIVE_PAYMENT_HELPER = ILensNativePaymentHelper(
            ILensCreate2(LENS_CREATE_2_ADDRESS).getAddress(CONTRACT__LENS_NATIVE_PAYMENT_HELPER)
        );
    }

    modifier usingNativePaymentHelper() {
        if (msg.value > 0) {
            (bool callSucceeded,) = address(LENS_NATIVE_PAYMENT_HELPER).call{value: msg.value}("");
            require(callSucceeded, Errors.FailedToTransferNative());
        }
        _;
        // We don't do the automatic refund here because of reentrancy and denial-of-service concerns.
        // One can always use multi-call to trigger refundNative() after all transactions are completed.
        // LENS_NATIVE_PAYMENT_HELPER.refundNative(msg.sender);
    }
}
