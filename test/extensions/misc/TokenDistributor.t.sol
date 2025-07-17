// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../helpers/TypeHelpers.sol";

import {FuzzZkTest} from "test/helpers/FuzzZkTest.sol";
import {TokenDistributor} from "contracts/extensions/misc/TokenDistributor.sol";
import {NATIVE_TOKEN} from "contracts/core/types/Constants.sol";
import {MockCurrency} from "test/mocks/MockCurrency.sol";
import {Errors} from "contracts/core/types/Errors.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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

    function testDeploying_SetsTheRightOwner_Constructor(address initialOwner) public {
        tokenDistributor = new TokenDistributor(initialOwner);
        assertEq(tokenDistributor.owner(), initialOwner);
    }

    function testDeploying_SetsTheRightOwner_AndCannotInitializeAfter(address initialOwner, address anotherOwner)
        public
    {
        vm.assume(initialOwner != anotherOwner);
        tokenDistributor = new TokenDistributor(initialOwner);
        assertEq(tokenDistributor.owner(), initialOwner);

        vm.expectRevert(Errors.AlreadyInitialized.selector);
        tokenDistributor.initialize(anotherOwner);

        assertEq(tokenDistributor.owner(), initialOwner);
    }

    function testDeploying_ThroughProxy_InitializerSetsRightOwner(
        address constructorOwner,
        address initializerOwner,
        address proxyAdmin
    ) public {
        vm.assume(constructorOwner != initializerOwner);
        vm.assume(proxyAdmin != address(this));
        address impl = address(new TokenDistributor(constructorOwner));

        bytes memory initializeCall = abi.encodeCall(TokenDistributor.initialize, (initializerOwner));
        tokenDistributor = TokenDistributor(address(new TransparentUpgradeableProxy(impl, proxyAdmin, initializeCall)));

        assertEq(TokenDistributor(impl).owner(), constructorOwner);

        assertEq(tokenDistributor.owner(), initializerOwner);

        vm.expectRevert(Errors.AlreadyInitialized.selector);
        tokenDistributor.initialize(constructorOwner);

        assertEq(tokenDistributor.owner(), initializerOwner);
    }

    function testCreateDistribution_withNative(uint256 amount, bytes32 paramKey, bytes32 paramValue) public {
        amount = _boundAmount(amount);
        vm.deal(owner, amount);

        uint256 balanceBefore = address(tokenDistributor).balance;

        uint256 predictedDistributionId = tokenDistributor.getDistributionCount() + 1;

        KeyValue[] memory params = new KeyValue[](1);
        params[0] = KeyValue({key: paramKey, value: abi.encode(paramValue)});

        vm.expectEmit(true, true, true, true);
        emit TokenDistributor.Lens_TokenDistributor_DistributionCreated(
            predictedDistributionId, NATIVE_TOKEN, amount, params
        );

        vm.prank(owner);
        uint256 distributionId = tokenDistributor.createDistribution{value: amount}(NATIVE_TOKEN, amount, params);

        assertEq(distributionId, predictedDistributionId, "distributionId mismatch");

        uint256 balanceAfter = address(tokenDistributor).balance;
        assertEq(balanceAfter, balanceBefore + amount, "tokenDistributor balance mismatch");

        TokenDistributor.Distribution memory distribution = tokenDistributor.getDistribution(distributionId);

        assertEq(distribution.token, NATIVE_TOKEN, "distribution token mismatch");
        assertEq(distribution.initialAmount, amount, "distribution amount mismatch");
        assertEq(distribution.remainingAmount, amount, "distribution remaining amount mismatch");
    }

    function testCreateDistribution_withERC20(uint256 amount, bytes32 paramKey, bytes32 paramValue) public {
        vm.assume(amount > 0);
        mockCurrency.mint(owner, amount);

        uint256 tokenDistributorBalanceBefore = mockCurrency.balanceOf(address(tokenDistributor));
        uint256 ownerBalanceBefore = mockCurrency.balanceOf(owner);

        uint256 predictedDistributionId = tokenDistributor.getDistributionCount() + 1;

        vm.prank(owner);
        mockCurrency.approve(address(tokenDistributor), amount);

        KeyValue[] memory params = new KeyValue[](1);
        params[0] = KeyValue({key: paramKey, value: abi.encode(paramValue)});

        vm.expectEmit(true, true, true, true);
        emit TokenDistributor.Lens_TokenDistributor_DistributionCreated(
            predictedDistributionId, address(mockCurrency), amount, params
        );

        vm.prank(owner);
        uint256 distributionId = tokenDistributor.createDistribution(address(mockCurrency), amount, params);

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

    function testEndDistribution_withNative_AndEndItImmediately(uint256 amount) public {
        amount = _boundAmount(amount);

        uint256 distributionId = _createDistribution(amount, true);

        uint256 ownerBalanceBefore = address(owner).balance;
        uint256 tokenDistributorBalanceBefore = address(tokenDistributor).balance;

        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, amount);
        assertEq(tokenDistributor.getDistribution(distributionId).initialAmount, amount);

        vm.prank(owner);
        tokenDistributor.endDistribution(distributionId);

        assertEq(address(owner).balance, ownerBalanceBefore + amount);
        assertEq(address(tokenDistributor).balance, tokenDistributorBalanceBefore - amount);
        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, 0);
        assertEq(tokenDistributor.getDistribution(distributionId).initialAmount, amount);
    }

    function testEndDistribution_withERC20_AndEndItImmediately(uint256 amount) public {
        amount = _boundAmount(amount);

        uint256 distributionId = _createDistribution(amount, false);

        uint256 ownerBalanceBefore = mockCurrency.balanceOf(owner);
        uint256 tokenDistributorBalanceBefore = mockCurrency.balanceOf(address(tokenDistributor));

        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, amount);
        assertEq(tokenDistributor.getDistribution(distributionId).initialAmount, amount);

        vm.prank(owner);
        tokenDistributor.endDistribution(distributionId);

        assertEq(mockCurrency.balanceOf(owner), ownerBalanceBefore + amount);
        assertEq(mockCurrency.balanceOf(address(tokenDistributor)), tokenDistributorBalanceBefore - amount);
        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, 0);
        assertEq(tokenDistributor.getDistribution(distributionId).initialAmount, amount);
    }

    function test_PartialDistribution_ProperBalances(uint256 amount, bytes32 batchId, uint256 deadline) public {
        address[] memory recipients = new address[](3);
        recipients[0] = makeAddr("RECIPIENT_1");
        recipients[1] = address(new RecipientThatCannotReceive());
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

        assertTrue(tokenDistributor.wasBatchProcessed(distributionId, batchId));
        assertEq(
            tokenDistributor.getDistribution(distributionId).remainingAmount,
            amount - transferAmounts[0] - transferAmounts[2]
        );

        assertEq(address(recipients[0]).balance, recipientBalancesBefore[0] + transferAmounts[0]);
        assertEq(address(recipients[1]).balance, recipientBalancesBefore[1]);
        assertEq(address(recipients[2]).balance, recipientBalancesBefore[2] + transferAmounts[2]);
    }

    function test_PartialDistribution_AndThenEndDistribution(uint256 amount, bytes32 batchId, uint256 deadline) public {
        address[] memory recipients = new address[](3);
        recipients[0] = makeAddr("RECIPIENT_1");
        recipients[1] = address(new RecipientThatCannotReceive());
        recipients[2] = makeAddr("RECIPIENT_3");

        uint256[] memory recipientBalancesBefore = new uint256[](3);
        recipientBalancesBefore[0] = address(recipients[0]).balance;
        recipientBalancesBefore[1] = address(recipients[1]).balance;
        recipientBalancesBefore[2] = address(recipients[2]).balance;

        amount = _boundAmount(amount);
        uint256 distributionId = _createDistribution(amount, true);

        uint256 ownerBalanceBefore = address(owner).balance;

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

        vm.prank(owner);
        tokenDistributor.endDistribution(distributionId);

        assertEq(address(owner).balance, ownerBalanceBefore + transferAmounts[1]);
    }

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
        tokenDistributor.createDistribution(NATIVE_TOKEN, amount, _emptyKeyValueArray());
    }

    function testCannot_createDistribution_ifNotOwner_withERC20(address nonOwner, uint256 amount) public {
        vm.assume(nonOwner != owner);
        amount = _boundAmount(amount);
        mockCurrency.mint(nonOwner, amount);
        vm.prank(nonOwner);
        mockCurrency.approve(address(tokenDistributor), amount);

        vm.expectRevert(Errors.InvalidMsgSender.selector);
        vm.prank(nonOwner);
        tokenDistributor.createDistribution(address(mockCurrency), amount, _emptyKeyValueArray());
    }

    function testCannot_createDistribution_ifAmountIsZero_withNative() public {
        vm.expectRevert(Errors.InvalidParameter.selector);
        vm.prank(owner);
        tokenDistributor.createDistribution(NATIVE_TOKEN, 0, _emptyKeyValueArray());
    }

    function testCannot_createDistribution_ifAmountIsZero_withERC20() public {
        vm.expectRevert(Errors.InvalidParameter.selector);
        vm.prank(owner);
        tokenDistributor.createDistribution(address(mockCurrency), 0, _emptyKeyValueArray());
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

    function testCannot_endDistribution_ifAllTokensDistributed(uint256 amount, bool useNative) public {
        amount = _boundAmount(amount);
        uint256 distributionId = _createDistribution(amount, useNative);
        uint256 deadline = block.timestamp + 2 minutes;
        bytes32 batchId = bytes32(uint256(69));

        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, amount);

        address recipient = makeAddr("RECIPIENT");
        TokenDistributor.TokenTransfer[] memory transfers = new TokenDistributor.TokenTransfer[](1);
        transfers[0] = TokenDistributor.TokenTransfer({recipient: recipient, amount: amount});
        bytes memory signature = _generateSignature(signerPk, distributionId, batchId, transfers, deadline);
        tokenDistributor.distributeTokens(distributionId, batchId, transfers, amount, deadline, signature);

        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, 0);

        vm.expectRevert(Errors.RedundantStateChange.selector);
        vm.prank(owner);
        tokenDistributor.endDistribution(distributionId);
    }

    function testCannot_distributeTokens_AfterSignatureDeadline(
        uint256 amount,
        bool useNative,
        uint256 blockTimestamp,
        uint256 sigDeadline
    ) public {
        blockTimestamp = _boundBlockTimestamp(blockTimestamp);
        sigDeadline = _boundBlockTimestamp(sigDeadline);
        vm.assume(sigDeadline < blockTimestamp);
        vm.warp(blockTimestamp);
        amount = _boundAmount(amount);
        uint256 distributionId = _createDistribution(amount, useNative);
        bytes32 batchId = bytes32(uint256(69));

        assertEq(tokenDistributor.getDistribution(distributionId).remainingAmount, amount);

        address recipient = makeAddr("RECIPIENT");
        TokenDistributor.TokenTransfer[] memory transfers = new TokenDistributor.TokenTransfer[](1);
        transfers[0] = TokenDistributor.TokenTransfer({recipient: recipient, amount: amount});
        bytes memory signature = _generateSignature(signerPk, distributionId, batchId, transfers, sigDeadline);

        vm.expectRevert(Errors.Expired.selector);
        tokenDistributor.distributeTokens(distributionId, batchId, transfers, amount, sigDeadline, signature);
    }

    function testCannot_distributeTokens_ifBatchIdAlreadyUsed(uint256 amount, bool useNative, bytes32 batchId) public {
        amount = _boundAmount(amount);
        uint256 distributionId = _createDistribution(amount, useNative);
        uint256 deadline = block.timestamp + 2 minutes;

        vm.assume(tokenDistributor.wasBatchProcessed(distributionId, batchId) == false);

        address recipient = makeAddr("RECIPIENT");
        TokenDistributor.TokenTransfer[] memory transfers = new TokenDistributor.TokenTransfer[](1);
        transfers[0] = TokenDistributor.TokenTransfer({recipient: recipient, amount: amount});
        bytes memory signature = _generateSignature(signerPk, distributionId, batchId, transfers, deadline);
        tokenDistributor.distributeTokens(distributionId, batchId, transfers, amount, deadline, signature);

        assertTrue(tokenDistributor.wasBatchProcessed(distributionId, batchId));

        vm.expectRevert(Errors.AlreadyProcessed.selector);
        tokenDistributor.distributeTokens(distributionId, batchId, transfers, amount, deadline, signature);
    }

    function testCannot_distributeTokens_ifAmountToDistributeIsLargerThanRemainingAmount(
        uint256 amount,
        bool useNative,
        uint256 amountToDistribute
    ) public {
        amount = _boundAmount(amount);
        vm.assume(amountToDistribute > amount);
        uint256 distributionId = _createDistribution(amount, useNative);
        uint256 deadline = block.timestamp + 2 minutes;
        bytes32 batchId = bytes32(uint256(69));

        address recipient = makeAddr("RECIPIENT");
        TokenDistributor.TokenTransfer[] memory transfers = new TokenDistributor.TokenTransfer[](1);
        transfers[0] = TokenDistributor.TokenTransfer({recipient: recipient, amount: amountToDistribute});
        bytes memory signature = _generateSignature(signerPk, distributionId, batchId, transfers, deadline);

        vm.expectRevert(Errors.InvalidParameter.selector);
        tokenDistributor.distributeTokens(distributionId, batchId, transfers, amountToDistribute, deadline, signature);
    }

    function testCannot_distributeTokens_ifAmountToDistribute_IsSmallerThan_SumOfAllTokenTransferAmounts(
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

        vm.expectRevert(Errors.InvalidParameter.selector);
        tokenDistributor.distributeTokens(distributionId, batchId, transfers, amount - 1, deadline, signature);
    }

    function testCannot_distributeTokens_ifAmountToDistribute_IsBiggerThan_SumOfAllTokenTransferAmounts(
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

        vm.expectRevert(Errors.InvalidParameter.selector);
        tokenDistributor.distributeTokens(distributionId, batchId, transfers, amount + 1, deadline, signature);
    }

    function testCannot_updateSigner_ifNotOwner(address nonOwner, address newSigner) public {
        vm.assume(nonOwner != owner);

        vm.expectRevert(Errors.InvalidMsgSender.selector);
        vm.prank(nonOwner);
        tokenDistributor.updateSigner(newSigner);
    }

    function testCannot_distributeTokens_ifSignerChangedAfterSignatureGeneration(
        uint256 amount,
        bool useNative,
        address newSigner
    ) public {
        vm.assume(newSigner != signer);
        amount = _boundAmount(amount);
        uint256 distributionId = _createDistribution(amount, useNative);
        uint256 deadline = block.timestamp + 2 minutes;
        bytes32 batchId = bytes32(uint256(69));

        address recipient = makeAddr("RECIPIENT");
        TokenDistributor.TokenTransfer[] memory transfers = new TokenDistributor.TokenTransfer[](1);
        transfers[0] = TokenDistributor.TokenTransfer({recipient: recipient, amount: amount});
        bytes memory signature = _generateSignature(signerPk, distributionId, batchId, transfers, deadline);

        vm.prank(owner);
        tokenDistributor.updateSigner(newSigner);

        vm.expectRevert(Errors.WrongSigner.selector);
        tokenDistributor.distributeTokens(distributionId, batchId, transfers, amount, deadline, signature);
    }

    function testCannot_transferOwnership_ifNotOwner(address nonOwner, address newOwner) public {
        vm.assume(nonOwner != owner);

        vm.expectRevert(Errors.InvalidMsgSender.selector);
        vm.prank(nonOwner);
        tokenDistributor.transferOwnership(newOwner);
    }

    // Helpers

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
        return tokenDistributor.createDistribution{value: msgValue}(token, amount, _emptyKeyValueArray());
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

contract RecipientThatCannotReceive {
    receive() external payable {
        revert();
    }
}
