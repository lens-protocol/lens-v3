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
    uint256 ownerPk;
    address owner;
    uint256 signerPk;
    address signer;

    MockCurrency mockCurrency;

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("OWNER");
        (signer, signerPk) = makeAddrAndKey("SIGNER");
        tokenDistributor = new TokenDistributor(owner);
        vm.prank(owner);
        tokenDistributor.updateSigner(signer);
        mockCurrency = new MockCurrency("Mock", "MCK");
    }

    ////// Scenarios

    function testDeploying_SetsTheRightOwner(address initialOwner) public {
        tokenDistributor = new TokenDistributor(initialOwner);
        assertEq(tokenDistributor.owner(), initialOwner);
    }

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

    // function testEndDistribution_withNative_immediately(uint256 amount) public {
    //     // Create distribution then end distribution - check native is returned back and distributeToken doesn't work
    // }

    // function testEndDistribution_withERC20_immediately(uint256 amount) public {
    //     // Create distribution then end distribution - check ERC20 is returned back and distributeToken doesn't work
    // }

    // EndDistribution after distributing partial should refund the remained (Native)

    // EndDistribution after distributing partial should refund the remained (ERC20)

    function testDistributeTokens_Native_allTransfersSucceedAndBalancesMatch(
        uint256 amount,
        bytes32 batchId,
        uint256 deadline
    ) public {
        address[] memory recipients = new address[](3);
        recipients[0] = makeAddr("RECIPIENT_1");
        recipients[1] = makeAddr("RECIPIENT_2");
        recipients[2] = makeAddr("RECIPIENT_3");

        uint256[] memory recipientBalancesBefore = new uint256[](3);
        recipientBalancesBefore[0] = address(recipients[0]).balance;
        recipientBalancesBefore[1] = address(recipients[1]).balance;
        recipientBalancesBefore[2] = address(recipients[2]).balance;

        amount = _boundAmount(amount);
        uint256 distributionId = _createDistribution(amount, true);

        vm.assume(deadline >= block.timestamp);

        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, amount);
        assertEq(tokenDistributor.getDistribution(distributionId).initialAmount, amount);
        assertEq(tokenDistributor.getDistribution(distributionId).token, NATIVE_TOKEN);

        vm.assume(amount / 3 > 0);
        uint256[] memory transferAmounts = new uint256[](3);
        transferAmounts[0] = amount / 3;
        transferAmounts[1] = amount / 3;
        transferAmounts[2] = amount - (amount / 3) * 2;
        TokenDistributor.TokenTransfer[] memory transfers = new TokenDistributor.TokenTransfer[](3);
        transfers[0] = TokenDistributor.TokenTransfer({recipient: recipients[0], amount: transferAmounts[0]});
        transfers[1] = TokenDistributor.TokenTransfer({recipient: recipients[1], amount: transferAmounts[1]});
        transfers[2] = TokenDistributor.TokenTransfer({recipient: recipients[2], amount: transferAmounts[2]});

        bytes memory signature = _generateSignature(signerPk, distributionId, batchId, transfers, deadline);

        tokenDistributor.distributeTokens(distributionId, batchId, transfers, amount, deadline, signature);

        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, 0);
        assertEq(tokenDistributor.getDistribution(distributionId).initialAmount, amount);
        assertEq(tokenDistributor.getDistribution(distributionId).token, NATIVE_TOKEN);

        assertEq(address(recipients[0]).balance, recipientBalancesBefore[0] + transferAmounts[0]);
        assertEq(address(recipients[1]).balance, recipientBalancesBefore[1] + transferAmounts[1]);
        assertEq(address(recipients[2]).balance, recipientBalancesBefore[2] + transferAmounts[2]);
    }

    function testDistributeTokens_ERC20_allTransfersSucceedAndBalancesMatch(
        uint256 amount,
        bytes32 batchId,
        uint256 deadline
    ) public {
        address[] memory recipients = new address[](3);
        recipients[0] = makeAddr("RECIPIENT_1");
        recipients[1] = makeAddr("RECIPIENT_2");
        recipients[2] = makeAddr("RECIPIENT_3");

        uint256[] memory recipientBalancesBefore = new uint256[](3);
        recipientBalancesBefore[0] = mockCurrency.balanceOf(address(recipients[0]));
        recipientBalancesBefore[1] = mockCurrency.balanceOf(address(recipients[1]));
        recipientBalancesBefore[2] = mockCurrency.balanceOf(address(recipients[2]));

        vm.assume(deadline >= block.timestamp);

        amount = _boundAmount(amount);
        uint256 distributionId = _createDistribution(amount, false);

        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, amount);
        assertEq(tokenDistributor.getDistribution(distributionId).initialAmount, amount);
        assertEq(tokenDistributor.getDistribution(distributionId).token, address(mockCurrency));

        vm.assume(amount / 3 > 0);
        uint256[] memory transferAmounts = new uint256[](3);
        transferAmounts[0] = amount / 3;
        transferAmounts[1] = amount / 3;
        transferAmounts[2] = amount - (amount / 3) * 2;
        TokenDistributor.TokenTransfer[] memory transfers = new TokenDistributor.TokenTransfer[](3);
        transfers[0] = TokenDistributor.TokenTransfer({recipient: recipients[0], amount: transferAmounts[0]});
        transfers[1] = TokenDistributor.TokenTransfer({recipient: recipients[1], amount: transferAmounts[1]});
        transfers[2] = TokenDistributor.TokenTransfer({recipient: recipients[2], amount: transferAmounts[2]});

        bytes memory signature = _generateSignature(signerPk, distributionId, batchId, transfers, deadline);

        tokenDistributor.distributeTokens(distributionId, batchId, transfers, amount, deadline, signature);

        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, 0);
        assertEq(tokenDistributor.getDistribution(distributionId).initialAmount, amount);
        assertEq(tokenDistributor.getDistribution(distributionId).token, address(mockCurrency));

        assertEq(mockCurrency.balanceOf(address(recipients[0])), recipientBalancesBefore[0] + transferAmounts[0]);
        assertEq(mockCurrency.balanceOf(address(recipients[1])), recipientBalancesBefore[1] + transferAmounts[1]);
        assertEq(mockCurrency.balanceOf(address(recipients[2])), recipientBalancesBefore[2] + transferAmounts[2]);
    }

    // DistributeTokens - Native partial distribution (some recipients failed to receive native)

    function testUpdateSigner(address newSigner) public {
        vm.prank(owner);
        tokenDistributor.updateSigner(newSigner);
        assertEq(tokenDistributor.getSigner(), newSigner);
    }

    function testTransferOwnership(address newOwner) public {
        vm.prank(owner);
        tokenDistributor.transferOwnership(newOwner);
        assertEq(tokenDistributor.owner(), newOwner);
    }

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
        amount = _boundAmount(amount);

        uint256 distributionId = _createDistribution(amount, useNative);

        vm.expectRevert(Errors.InvalidMsgSender.selector);
        vm.prank(nonOwner);
        tokenDistributor.endDistribution(distributionId);
    }

    function testCannot_endDistribution_ifAlreadyEnded(uint256 amount, bool useNative) public {
        amount = _boundAmount(amount);
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

    function testCannot_transferOwnership_ifNotOwner(address nonOwner, address newOwner) public {
        vm.assume(nonOwner != owner);

        vm.expectRevert(Errors.InvalidMsgSender.selector);
        vm.prank(nonOwner);
        tokenDistributor.transferOwnership(newOwner);
    }

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

    // Signature generation

    bytes32 constant DISTRIBUTE_TOKENS_TYPEHASH = keccak256(
        "DistributeTokens(uint256 distributionId,bytes32 batchId,TokenTransfer[] transfers,uint256 deadline)TokenTransfer(address recipient,uint256 amount)"
    );

    function _generateSignature(
        uint256 pkToSignWith,
        uint256 distributionId,
        bytes32 batchId,
        TokenDistributor.TokenTransfer[] memory transfers,
        uint256 deadline
    ) internal pure returns (bytes memory) {
        bytes32 digest = _calculateDigest(distributionId, batchId, transfers, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkToSignWith, digest);
        return abi.encodePacked(r, s, v);
    }

    function _calculateDigest(
        uint256 distributionId,
        bytes32 batchId,
        TokenDistributor.TokenTransfer[] memory transfers,
        uint256 deadline
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(DISTRIBUTE_TOKENS_TYPEHASH, distributionId, batchId, _encodeForEIP712(transfers), deadline)
        );
    }

    function _encodeForEIP712(TokenDistributor.TokenTransfer memory tokenTransfer) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("TokenTransfer(address recipient,uint256 amount)"), // Type Hash
                tokenTransfer.recipient,
                tokenTransfer.amount
            )
        );
    }

    function _encodeForEIP712(TokenDistributor.TokenTransfer[] memory tokenTransferArray)
        internal
        pure
        returns (bytes32)
    {
        bytes32[] memory tokenTransferEncodedElements = new bytes32[](tokenTransferArray.length);
        for (uint256 i = 0; i < tokenTransferArray.length; i++) {
            tokenTransferEncodedElements[i] = _encodeForEIP712(tokenTransferArray[i]);
        }
        return _encodeForEIP712(tokenTransferEncodedElements);
    }

    function _encodeForEIP712(bytes32[] memory bytes32Array) internal pure returns (bytes32) {
        return keccak256(abi.encode(bytes32Array));
    }
}
