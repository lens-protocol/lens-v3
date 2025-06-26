// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {FuzzZkTest} from "test/helpers/FuzzZkTest.sol";
import {TokenDistributor} from "contracts/extensions/misc/TokenDistributor.sol";
import {NATIVE_TOKEN} from "contracts/core/types/Constants.sol";
import {MockCurrency} from "test/mocks/MockCurrency.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract TokenDistributorTest is FuzzZkTest {
    TokenDistributor tokenDistributor;
    address owner = makeAddr("OWNER");
    address signer = makeAddr("SIGNER");

    MockCurrency mockCurrency;

    function setUp() public {
        tokenDistributor = new TokenDistributor(owner);
        vm.prank(owner);
        tokenDistributor.updateSigner(signer);
        mockCurrency = new MockCurrency("Mock", "MCK");
    }

    ////// Scenarios

    function testCreateDistribution_withNative(uint256 amount) public {
        amount = _boundAmount(amount);
        vm.deal(owner, amount);

        uint256 balanceBefore = address(tokenDistributor).balance;

        uint256 predictedDistributionId = tokenDistributor.getDistributionCount() + 1;

        vm.expectEmit(true, true, true, true);
        emit TokenDistributor.Lens_TokenDistributor_DistributionCreated(predictedDistributionId, NATIVE_TOKEN, amount);

        vm.prank(owner);
        uint256 distributionId = tokenDistributor.createDistribution{value: amount}(NATIVE_TOKEN, amount);

        assertEq(distributionId, predictedDistributionId, "distributionId mismatch");

        uint256 balanceAfter = address(tokenDistributor).balance;
        assertEq(balanceAfter, balanceBefore + amount, "tokenDistributor balance mismatch");

        TokenDistributor.Distribution memory distribution = tokenDistributor.getDistribution(distributionId);

        assertEq(distribution.token, NATIVE_TOKEN, "distribution token mismatch");
        assertEq(distribution.initialAmount, amount, "distribution amount mismatch");
        assertEq(distribution.remainingAmount, amount, "distribution remaining amount mismatch");
    }

    function testCreateDistribution_withERC20(uint256 amount) public {
        vm.assume(amount > 0);
        mockCurrency.mint(owner, amount);

        uint256 tokenDistributorBalanceBefore = mockCurrency.balanceOf(address(tokenDistributor));
        uint256 ownerBalanceBefore = mockCurrency.balanceOf(owner);

        uint256 predictedDistributionId = tokenDistributor.getDistributionCount() + 1;

        vm.prank(owner);
        mockCurrency.approve(address(tokenDistributor), amount);

        vm.expectEmit(true, true, true, true);
        emit TokenDistributor.Lens_TokenDistributor_DistributionCreated(
            predictedDistributionId, address(mockCurrency), amount
        );

        vm.prank(owner);
        uint256 distributionId = tokenDistributor.createDistribution(address(mockCurrency), amount);

        assertEq(distributionId, predictedDistributionId, "distributionId mismatch");

        uint256 tokenDistributorBalanceAfter = mockCurrency.balanceOf(address(tokenDistributor));
        assertEq(
            tokenDistributorBalanceAfter, tokenDistributorBalanceBefore + amount, "tokenDistributor balance mismatch"
        );

        uint256 ownerBalanceAfter = mockCurrency.balanceOf(owner);
        assertEq(ownerBalanceAfter, ownerBalanceBefore - amount, "owner balance mismatch");

        TokenDistributor.Distribution memory distribution = tokenDistributor.getDistribution(distributionId);

        assertEq(distribution.token, address(mockCurrency), "distribution token mismatch");
        assertEq(distribution.initialAmount, amount, "distribution amount mismatch");
        assertEq(distribution.remainingAmount, amount, "distribution remaining amount mismatch");
    }

    function testEndDistribution_withNative_immediately(uint256 amount) public {
        // Create distribution then end distribution - check native is returned back and distributeToken doesn't work
    }

    function testEndDistribution_withERC20_immediately(uint256 amount) public {
        // Create distribution then end distribution - check ERC20 is returned back and distributeToken doesn't work
    }

    // EndDistribution after distributing partial should refund the remained (Native)

    // EndDistribution after distributing partial should refund the remained (ERC20)

    // DistributeTokens - Native (all transfers succeed and balances match)

    // DistributeTokens - ERC20 (all transfers succeed and balances match)

    // DistributeTokens - Native partial distribution (some recipients failed to receive native)

    // UpdateSigner updates the signer address

    // Can transferOwnership (if owner)

    ////// Negatives

    function testCannot_createDistribution_ifNotOwner_withNative(address nonOwner, uint256 amount) public {
        vm.assume(nonOwner != owner);
        amount = _boundAmount(amount);
        vm.deal(nonOwner, amount);

        vm.expectRevert(Errors.InvalidMsgSender.selector);
        vm.prank(nonOwner);
        tokenDistributor.createDistribution(NATIVE_TOKEN, amount);
    }

    function testCannot_createDistribution_ifNotOwner_withERC20(address nonOwner, uint256 amount) public {
        vm.assume(nonOwner != owner);
        amount = _boundAmount(amount);
        mockCurrency.mint(nonOwner, amount);
        vm.prank(nonOwner);
        mockCurrency.approve(address(tokenDistributor), amount);

        vm.expectRevert(Errors.InvalidMsgSender.selector);
        vm.prank(nonOwner);
        tokenDistributor.createDistribution(address(mockCurrency), amount);
    }

    function testCannot_createDistribution_ifAmountIsZero_withNative() public {
        vm.expectRevert(Errors.InvalidParameter.selector);
        vm.prank(owner);
        tokenDistributor.createDistribution(NATIVE_TOKEN, 0);
    }

    function testCannot_createDistribution_ifAmountIsZero_withERC20() public {
        vm.expectRevert(Errors.InvalidParameter.selector);
        vm.prank(owner);
        tokenDistributor.createDistribution(address(mockCurrency), 0);
    }

    function testCannot_endDistribution_ifNotOwner(address nonOwner, uint256 amount, bool useNative) public {
        vm.assume(nonOwner != owner);

        uint256 distributionId = _createDistribution(amount, useNative);

        vm.expectRevert(Errors.InvalidMsgSender.selector);
        vm.prank(nonOwner);
        tokenDistributor.endDistribution(distributionId);
    }

    function testCannot_endDistribution_ifAlreadyEnded(uint256 amount, bool useNative) public {
        uint256 distributionId = _createDistribution(amount, useNative);

        vm.prank(owner);
        tokenDistributor.endDistribution(distributionId);

        vm.expectRevert(Errors.RedundantStateChange.selector);
        vm.prank(owner);
        tokenDistributor.endDistribution(distributionId);
    }

    // Cannot endDistribution if all tokens distributed, and remainingAmount is 0

    // Cannot Distribute tokens if after deadline

    // Cannot Distribute tokens if any part of the signature is wrong

    // Cannot Distribute tokens if the same batchId was already used and processed

    // Cannot Distribute tokens if amountToDistribute is larger than remainingAmount in the Distribution

    // Cannot Distribute tokens if amountToDistribute is smaller the sum of all TokenTransfer amounts (put more balance on the contract to not fail with not enough balance)

    function testCannot_updateSigner_ifNotOwner(address nonOwner, address newSigner) public {
        vm.assume(nonOwner != owner);

        vm.expectRevert(Errors.InvalidMsgSender.selector);
        vm.prank(nonOwner);
        tokenDistributor.updateSigner(newSigner);
    }

    // Cannot Distribute if the signer was changed and the signature is no longer valid

    // Cannot transferOwnership if not Owner

    ////// Getters

    // getDistribution

    // getDistributionCount

    // getSigner

    // wasBatchProcessed

    // owner()

    ////// Make sure to test all the events are emitted

    /*
    /////////////////////// SPEC /////////////////////////

    ////// Mark these as done when verified that the contract follows the points in spec

    The system must be able to:
    [ ] Send tokens to recipients
        [ ] Based on a precomputed (by backend) list of {token,amount,recipient}
        [ ] Don't fail the entire thing if single transfer fails
        [ ] Prevent replay sending if a given transfer already succeeded (batch IDs)
        [ ] Emit events on successful transfers (and maybe failed too) so Backend can track & adjust & resubmit the failed ones
        [ ] Accept & Hold Deposited Funds on it's balance
    [ ] Only callable with permission
        [ ] Ideally with signatures (so EOA msg.sender doesn't matter: paymaster & throw[ ]away EOAs) by a trusted signer
    [ ] Transfers would be periodic (weekly) but can be vested anytime with the config (BE only cares)
    [ ] Token support:
        [ ] Native GHO
        [ ] ERC20 (in future)
    [ ] Ownable
        [ ] Owner can EmergencyWithdraw
        [ ] Owner can change the TrustedSigner
    [ ] Emergency Withdrawal (by Owner)
    [ ] Upgradeable
    [ ] Tracking Distributions (managing the funds, limiting & protecting)
        [ ] Deposit(token, amount) returns (uint256 distributionID)
            [ ] Amount
            [ ] Token
        [ ] Then on Distribute(with this ID) the amount is subtracted with every Transfer and cannot be more than the Distribution had
        [ ] Withdraw() full balance cancels further distribution and invalidates the DistributionID
    */

    function _createDistribution(uint256 amount, bool useNative) internal returns (uint256) {
        return _createDistribution(useNative ? NATIVE_TOKEN : address(mockCurrency), amount);
    }

    function _createDistribution(address token, uint256 amount) internal returns (uint256) {
        amount = _boundAmount(amount);
        uint256 msgValue;
        if (token == NATIVE_TOKEN) {
            vm.deal(owner, amount);
            msgValue = amount;
        } else {
            mockCurrency.mint(owner, amount);
            vm.prank(owner);
            mockCurrency.approve(address(tokenDistributor), amount);
        }
        vm.prank(owner);
        return tokenDistributor.createDistribution{value: msgValue}(token, amount);
    }
}
