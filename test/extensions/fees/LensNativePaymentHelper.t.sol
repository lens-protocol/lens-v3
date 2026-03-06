// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "./../../helpers/TypeHelpers.sol";

import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {FuzzZkTest} from "test/helpers/FuzzZkTest.sol";
import {Errors} from "@core/types/Errors.sol";
import {LensNativePaymentHelper} from "@extensions/fees/LensNativePaymentHelper.sol";

contract LensNativePaymentHelperTest is FuzzZkTest, BaseDeployments {
    function setUp() public override {
        super.setUp();

        lensNativePaymentHelper = payable(new LensNativePaymentHelper());
    }

    function test_LensNativePaymentHelper_CanReceiveFunds(uint256 msgValue) public {
        msgValue = _boundAmount(msgValue);
        vm.deal(address(this), msgValue);

        assertEq(address(lensNativePaymentHelper).balance, 0);

        (bool callSucceeded,) = address(lensNativePaymentHelper).call{value: msgValue}("");
        assertTrue(callSucceeded);

        assertEq(address(lensNativePaymentHelper).balance, msgValue);
    }

    function test_LensNativePaymentHelper_CanTransferFundsToAddress(uint256 initialValue, uint256 transferAmount)
        public
    {
        initialValue = _boundAmount(initialValue);
        vm.deal(address(this), initialValue);
        transferAmount = _boundAmount(transferAmount);
        vm.assume(transferAmount <= initialValue);

        (bool callSucceeded,) = address(lensNativePaymentHelper).call{value: initialValue}("");
        assertTrue(callSucceeded);

        assertEq(address(lensNativePaymentHelper).balance, initialValue);

        address receiver = makeAddr("RECEIVER");

        vm.assume(receiver.balance == 0);

        LensNativePaymentHelper(lensNativePaymentHelper).transferNative(receiver, transferAmount);

        assertEq(receiver.balance, transferAmount);
        assertEq(address(lensNativePaymentHelper).balance, initialValue - transferAmount);
    }

    function test_LensNativePaymentHelper_RevertsIfTransferAmountIsGreaterThanBalance(
        uint256 initialValue,
        uint256 transferAmount
    ) public {
        initialValue = _boundAmount(initialValue);
        vm.deal(address(this), initialValue);
        transferAmount = _boundAmount(transferAmount);
        vm.assume(transferAmount > initialValue);

        (bool callSucceeded,) = address(lensNativePaymentHelper).call{value: initialValue}("");
        assertTrue(callSucceeded);

        vm.expectRevert(Errors.NotEnoughBalance.selector);
        LensNativePaymentHelper(lensNativePaymentHelper).transferNative(address(this), transferAmount);
    }

    function test_LensNativePaymentHelper_CanRefundNative(uint256 initialValue, uint256 transferAmount) public {
        initialValue = _boundAmount(initialValue);
        vm.deal(address(this), initialValue);
        transferAmount = _boundAmountAllowZero(transferAmount);
        vm.assume(transferAmount <= initialValue);

        (bool callSucceeded,) = address(lensNativePaymentHelper).call{value: initialValue}("");
        assertTrue(callSucceeded);

        assertEq(address(lensNativePaymentHelper).balance, initialValue);

        address receiver = makeAddr("RECEIVER");

        vm.assume(receiver.balance == 0);

        LensNativePaymentHelper(lensNativePaymentHelper).transferNative(receiver, transferAmount);

        assertEq(receiver.balance, transferAmount);
        assertEq(address(lensNativePaymentHelper).balance, initialValue - transferAmount);

        LensNativePaymentHelper(lensNativePaymentHelper).refundNative(receiver);

        assertEq(address(lensNativePaymentHelper).balance, 0);
        assertEq(receiver.balance, initialValue);
    }
}
